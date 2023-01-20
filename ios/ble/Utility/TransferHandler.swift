
import Foundation

@available(iOS 13.0, *)
class TransferHandler {
    var data: Data?
    private var currentState: States = States.UnInitialised
    private var responseStartTimeInMillis: UInt64 = 0
    var chunker: Chunker?
    
    public static var shared = TransferHandler()
    
    func initialize(initdData: Data) {
        data = initdData
    }
    
    func sendMessage(message: imessage) {
        handleMessage(msg: message)
    }
    deinit{
        print("deinit happend in transferh")
    }
    private func handleMessage(msg: imessage){
        if msg.msgType == .INIT_RESPONSE_TRANSFER {
            var responseData = msg.data!
            print("Total response size of data",responseData.count)
            chunker = Chunker(chunkData: responseData, mtuSize: BLEConstants.DEFAULT_CHUNK_SIZE)
            print("MTU found to be", BLEConstants.DEFAULT_CHUNK_SIZE)
            currentState = States.ResponseSizeWritePending
            sendMessage(message: imessage(msgType: .ResponseSizeWritePendingMessage, data: responseData, dataSize: responseData.count))
        }
        else if msg.msgType == .ResponseSizeWritePendingMessage {
            sendResponseSize(size: msg.dataSize!)
        }
        else if msg.msgType == .RESPONSE_SIZE_WRITE_SUCCESS {
          responseStartTimeInMillis = Utils.currentTimeInMilliSeconds()
          currentState = States.ResponseSizeWriteSuccess
          initResponseChunkSend()
        } else if msg.msgType == .INIT_RESPONSE_CHUNK_TRANSFER {
            currentState = .ResponseWritePending
            sendResponseChunk()
        }
        else if msg.msgType == .READ_TRANSMISSION_REPORT {
            currentState = States.WaitingForTransferReport
            requestTransmissionReport()
        }
        else if msg.msgType == .HANDLE_TRANSMISSION_REPORT {
            currentState = States.HandlingTransferReport
            var handleTransmissionReportMessage = msg.data
            handleTransmissionReport(report: handleTransmissionReportMessage!)
        }
        else {
            print("out of scope")
        }
    }
    
    private func requestTransmissionReport() {
        var notifyObj: Data = Data()
        Central.shared.write(serviceUuid: BLEConstants.SERVICE_UUID, charUUID: TransferService.semaphoreCharacteristic, data: withUnsafeBytes(of: 1.bigEndian) { Data($0) })
        NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: "HANDLE_TRANSMISSION_REPORT"), object: nil, queue: nil) { [unowned self] notification in
            print("Handling notification for \(notification.name.rawValue)")
            notifyObj = notification.object as! Data
        }
        sendMessage(message: imessage(msgType: .HANDLE_TRANSMISSION_REPORT, data: notifyObj))
    }

    private func handleTransmissionReport(report: Data) {
//       if (report.type == TransferReport.ReportType.SUCCESS) {
//         currentState = States.TransferVerified
//         transferListener.onResponseSent()
//         print(logTag, "handleMessage: Successfully transferred vc in ${System.currentTimeMillis() - responseStartTimeInMillis}ms")
//       } else if(report.type == TransferReport.ReportType.MISSING_CHUNKS && report.missingSequences != null && !isRetryFrame) {
//         currentState = States.PartiallyTransferred
//         this.sendMessage(InitRetryTransferMessage(report.missingSequences))
//       } else {
//         this.sendMessage(ResponseTransferFailureMessage("Invalid Report"))
//       }
        print("report is :::", String(data: report, encoding: .utf8))
     }

    private func sendResponseSize(size: Int) {
        let dataSize = withUnsafeBytes(of: size.bigEndian) { Data($0) }
        Central.shared.write(serviceUuid: Peripheral.SERVICE_UUID, charUUID: TransferService.responseSizeCharacteristic, data: dataSize)
        NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: "RESPONSE_SIZE_WRITE_SUCCESS"), object: nil, queue: nil) { [unowned self] notification in
            print("Handling notification for \(notification.name.rawValue)")
            sendMessage(message: imessage(msgType: .RESPONSE_SIZE_WRITE_SUCCESS, data: data))
        }
    }
    
    private func initResponseChunkSend() {
         print("initResponseChunkSend")
        sendMessage(message: imessage(msgType: .INIT_RESPONSE_CHUNK_TRANSFER, data: data, dataSize: data?.count))
    }
    
    private func sendResponseChunk() {
        if let chunker = chunker {
            if chunker.isComplete() {
                print("Data send complete")
                sendMessage(message: imessage(msgType: .READ_TRANSMISSION_REPORT))
                return
            }

            var done = false
            while !done {
                let chunk = chunker.next()
                if chunk.isEmpty {
                    done = true
                    sendMessage(message: imessage(msgType: .INIT_RESPONSE_CHUNK_TRANSFER, data: data, dataSize: data?.count))
                }
                else {
                    Central.shared.write(serviceUuid: Peripheral.SERVICE_UUID, charUUID: TransferService.responseCharacteristic, data: chunk)
                }
                
            }
        }
    }
}

enum TransferMessageTypes {
    case INIT_RESPONSE_TRANSFER
    case ResponseSizeWritePendingMessage
    case RESPONSE_SIZE_WRITE_SUCCESS
    case INIT_RESPONSE_CHUNK_TRANSFER
    case RESPONSE_TRANSFER_COMPLETE
    case READ_TRANSMISSION_REPORT
    case HANDLE_TRANSMISSION_REPORT
}

struct imessage {
    var msgType: TransferMessageTypes
    var data: Data?
    var dataSize: Int?
}

enum  States {
    case UnInitialised
    case ResponseSizeWritePending
    case ResponseSizeWriteSuccess
    case ResponseSizeWriteFailed
    case ResponseWritePending
    case ResponseWriteFailed
    case TransferComplete
    case WaitingForTransferReport
    case HandlingTransferReport
    case TransferVerified
    case PartiallyTransferred
}

enum SemaphoreMarker: Int {
    case UnInitialised = 0
    case RequestReport = 1
    case Error = 2
  }