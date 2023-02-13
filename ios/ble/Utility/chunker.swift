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
        print("preSlicedChunks called ::: ")
        print("expected total data size: \(chunkData?.count) and totalChunkCount: \(totalChunkCount)")
        print(">> SHA256 \(String(describing: chunkData?.sha256()))")
        for i in 0..<totalChunkCount {
            preSlicedChunks.append(chunk(seqNumber: i))
        }
    }

    func getTotalChunkCount(dataSize: Int) -> Double {
        var resulydouble = Double(dataSize)/Double(effectivePayloadSize)
        return Double(ceill(resulydouble))
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
        var seqNumber = chunksReadCounter
        chunksReadCounter += 1
        if seqNumber <= totalChunkCount - 1 {
            return (preSlicedChunks[seqNumber])
        }
       else
        {
           return Data()
       }
    }

    func chunkBySequenceNumber(num: Int) -> Data {
        return (preSlicedChunks[num])
    }

    private func chunk(seqNumber: Int) -> Data {
        let fromIndex = seqNumber * effectivePayloadSize
        if (seqNumber == (totalChunkCount - 1) && lastChunkByteCount > 0) {
            print( "fetching last chunk")
            let chunkLength = lastChunkByteCount + chunkMetaSize
            return frameChunk(seqNumber: seqNumber, chunkLength: chunkLength, fromIndex: fromIndex, toIndex: fromIndex + lastChunkByteCount)
        } else {
            let toIndex = (seqNumber + 1) * effectivePayloadSize
            return frameChunk(seqNumber: seqNumber, chunkLength: mtuSize, fromIndex: fromIndex, toIndex: toIndex)
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

    private func frameChunk(seqNumber: Int, chunkLength: Int, fromIndex: Int, toIndex: Int) -> Data {
//        return intToTwoBytesBigEndian(num: seqNumber) + intToTwoBytesBigEndian(num: chunkLength) + chunkData!.subdata(in: fromIndex..<toIndex)
        if let chunkData = chunkData {
            let payload = chunkData.subdata(in: fromIndex + chunkData.startIndex..<chunkData.startIndex + toIndex)
            let payloadCRC = CRC.evaluate(d: payload)
            return Utils.intToBytes(UInt16(seqNumber)) + Utils.intToBytes(payloadCRC) + payload
        }
        return Data() //
    }

    func isComplete() -> Bool {
        let isComplete = chunksReadCounter > (totalChunkCount - 1)
        if isComplete {
            print("isComplete: true, totalChunks: \(totalChunkCount) , chunkReadCounter(1-indexed): \(chunksReadCounter)")
        }
       return isComplete
    }

//    func intToTwoBytesBigEndian(num: Int) -> [UInt8] {
//        if num < 256 {
//            let minValue: UInt8 = 0
//            return [minValue, UInt8(num)]
//        }
//        return [UInt8(num/256), UInt8(num%256)]
//    }

}

