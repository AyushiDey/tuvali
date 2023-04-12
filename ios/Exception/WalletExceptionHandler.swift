import Foundation

class WalletExceptionHandler {

    private var onError: ((_ message: String) -> Void)?
    var wallet: Wallet?
    
    init(err: (@escaping (String) -> Void)) {
        self.onError = err
    }

    func handle(error: WalletErrorEnum) {
        os_log(.error, "Error in OpenID4vBLE: %{public}@", error.description)
        self.onError(description: error.description)
    }
}

enum WalletErrorEnum: Error {
    case invalidMTUSizeError(mtu: Int)
    case responseTransferFailure
}

extension WalletErrorEnum: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalidMTUSizeError(let mtu):
            return "Negotiated MTU: \(mtu) is too low."
        case .responseTransferFailure:
            return "failed to write response"
        }
    }
}