import Foundation
import CoreBluetooth
import os

@available(iOS 13.0, *)
class Central: NSObject, CBCentralManagerDelegate {

    var retryStrategy : BackOffStrategy = BackOffStrategy(MAX_RETRY_LIMIT: 10)

    private var centralManager: CBCentralManager!
    var connectedPeripheral: CBPeripheral?
    var cbCharacteristics: [String: CBCharacteristic] = [:]

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Central Manager state is powered ON")
            scanForPeripherals()
        default:
            print("Central Manager is in powered OFF")
        }
    }

    deinit {
        print("Central is DeInitializing")
    }

    func connectToPeripheral(peripheral: CBPeripheral) {
        self.connectedPeripheral = peripheral
        self.connectedPeripheral?.delegate = self
        if let connectedPeripheral = self.connectedPeripheral {
            self.centralManager.connect(connectedPeripheral)
        }
    }

    func scanForPeripherals() {
        centralManager.scanForPeripherals(withServices: [Peripheral.SERVICE_UUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    /**
     * write(..) writes data on a charUUID without response
     */
    func write(serviceUuid: CBUUID, charUUID: CBUUID, data: Data) {
        if let connectedPeripheral = connectedPeripheral {
            if connectedPeripheral.canSendWriteWithoutResponse {
                guard let characteristic = self.cbCharacteristics[charUUID.uuidString] else {
                    print("Did not find the characteristic to write")
                    return
                }
                let messageData = Data(bytes: Array(data), count: data.count)
                connectedPeripheral.writeValue(messageData, for: characteristic, type: .withResponse)
            }
        }
    }

    /**
     * writeWithoutResp(...) writes data on a charUUID without response
     */
    func writeWithoutResp(serviceUuid: CBUUID, charUUID: CBUUID, data: Data) {
        if let connectedPeripheral = connectedPeripheral {
            guard let characteristic = self.cbCharacteristics[charUUID.uuidString] else {
                print("Did not find the characteristic to write")
                return
            }
            let messageData = Data(bytes: Array(data), count: data.count)
            connectedPeripheral.writeValue(messageData, for: characteristic, type: .withoutResponse)
        }
    }
}
