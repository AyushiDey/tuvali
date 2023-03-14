import Foundation

class Chunker {

    private var logTag = "Chunker"
    private var chunksReadCounter: Int = 0
    private var preSlicedChunks: [Data] = []
    private var chunkData: Data?
    private var mtuSize: Int = BLEConstants.DEFAULT_CHUNK_SIZE
    private var chunkMetaSize = BLEConstants.seqNumberReservedByteSize + BLEConstants.mtuReservedByteSize

    init(chunkData: Data, mtuSize: Int?) {
        self.chunkData = chunkData
        self.mtuSize = mtuSize!
        assignPreSlicedChunks()
    }

    func getChunkWithIndex(index: Int) -> Data {
        if index < self.preSlicedChunks.count {
            return self.preSlicedChunks[index]
        }
        // TODO: Figure out how to throw errors!
        return Data()
    }

    func getLastChunkByteCount(dataSize: Int) -> Int {
        return dataSize % effectivePayloadSize
    }

    func assignPreSlicedChunks(){
        os_log(.info, "expected total data size: %{public}d and totalChunkCount: %{public}d ", (chunkData?.count)!, totalChunkCount)
        for i in 0..<totalChunkCount {
            preSlicedChunks.append(chunk(seqIndex: i))
        }
    }

    func getTotalChunkCount(dataSize: Int) -> Double {
        var totalChunkCount = Double(dataSize)/Double(effectivePayloadSize)
        return Double(ceill(totalChunkCount))
    }

    var lastChunkByteCount: Int {
        return getLastChunkByteCount(dataSize: chunkData!.count)
    }

    var totalChunkCount: Int {
        return Int(getTotalChunkCount(dataSize: chunkData!.count))
    }

    var effectivePayloadSize: Int {
       return mtuSize - chunkMetaSize
    }

    func next() -> Data {
        var seqIndex = chunksReadCounter
        chunksReadCounter += 1
        if seqIndex <= totalChunkCount - 1 {
            return (preSlicedChunks[seqIndex])
        }
       else
        {
           return Data()
       }
    }

    func chunkBySequenceNumber(num: Int) -> Data {
        return (preSlicedChunks[num])
    }

    private func chunk(seqIndex: Int) -> Data {
        let fromIndex = seqIndex * effectivePayloadSize
        if (seqIndex == (totalChunkCount - 1) && lastChunkByteCount > 0) {
            let chunkLength = lastChunkByteCount + chunkMetaSize
            return frameChunk(seqIndex: seqIndex, chunkLength: chunkLength, fromIndex: fromIndex, toIndex: fromIndex + lastChunkByteCount)
        } else {
            let toIndex = (seqIndex + 1) * effectivePayloadSize
            return frameChunk(seqIndex: seqIndex, chunkLength: mtuSize, fromIndex: fromIndex, toIndex: toIndex)
        }
    }

    /*
     <------------------------------------------------------- MTU ------------------------------------------------------------------->
     +-----------------------+-----------------------------+-------------------------------------------------------------------------+
     |                       |                             |                                                                         |
     |  chunk sequence no    |     total chunk length      |         chunk payload                                                   |
     |      (2 bytes)        |         (2 bytes)           |       (upto MTU-4 bytes)                                                |
     |                       |                             |                                                                         |
     +-----------------------+-----------------------------+-------------------------------------------------------------------------+
     */

    private func frameChunk(seqIndex: Int, chunkLength: Int, fromIndex: Int, toIndex: Int) -> Data {
        let seqNumber = seqIndex + 1
        if let chunkData = chunkData {
            let payload = Utils.intToBytes(UInt16(seqNumber)) + chunkData.subdata(in: fromIndex + chunkData.startIndex..<chunkData.startIndex + toIndex)
            let payloadCRC = CRCValidator.calculate(d: payload)
            return payload + Utils.intToBytes(payloadCRC)
        }
        return Data()
    }

    func isComplete() -> Bool {
        let isComplete = chunksReadCounter > (totalChunkCount - 1)
        if isComplete {
            os_log(.info, "isComplete: true, totalChunks: %{public}d , chunkReadCounter(1-indexed): %{public}d", totalChunkCount, chunksReadCounter)
        }
       return isComplete
    }
}
