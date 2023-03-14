
import Foundation

protocol PeripheralCommunicatorProtocol: AnyObject {
    func onTransmissionReportRequest(data: Data)
    func onResponseSizeWriteSuccess()
    func onVerificationStatusChange(status: Int)
    func onFailedToSendTransferReportRequest()
}

protocol WalletProtocol: AnyObject {
    func onIdentifyWriteSuccess()
    func onDisconnectStatusChange(connectionStatusId: Int)
}
