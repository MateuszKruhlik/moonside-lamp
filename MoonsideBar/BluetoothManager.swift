import AppKit
import CoreBluetooth
import Foundation

final class BluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {

    // MARK: - NUS UUIDs

    static let nusServiceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    static let nusRXCharUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    static let knownPeripheralUUID = UUID(uuidString: "REMOVED")!

    // MARK: - Callbacks

    var onConnectionStatusChanged: ((ConnectionStatus) -> Void)?

    // MARK: - Private

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var rxCharacteristic: CBCharacteristic?
    private var retryCount = 0
    private let maxRetries = 10
    private var retryTimer: Timer?
    private var commandQueue: [String] = []

    // MARK: - Init

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        setupSleepWakeNotifications()
    }

    // MARK: - Public

    func send(_ command: String) {
        guard let peripheral, let rx = rxCharacteristic,
              peripheral.state == .connected else {
            // Queue command for when we reconnect
            commandQueue.append(command)
            return
        }
        guard let data = command.data(using: .utf8) else { return }
        let writeType: CBCharacteristicWriteType = rx.properties.contains(.writeWithoutResponse)
            ? .withoutResponse : .withResponse
        peripheral.writeValue(data, for: rx, type: writeType)
    }

    func connect() {
        guard centralManager.state == .poweredOn else { return }

        // Try to retrieve known peripheral first (faster than scanning)
        let known = centralManager.retrievePeripherals(withIdentifiers: [Self.knownPeripheralUUID])
        if let p = known.first {
            peripheral = p
            p.delegate = self
            centralManager.connect(p)
            onConnectionStatusChanged?(.connecting)
        } else {
            // Fall back to scanning
            centralManager.scanForPeripherals(withServices: [Self.nusServiceUUID])
            onConnectionStatusChanged?(.connecting)
        }
    }

    func disconnect() {
        retryTimer?.invalidate()
        retryTimer = nil
        if let p = peripheral {
            centralManager.cancelPeripheralConnection(p)
        }
        onConnectionStatusChanged?(.disconnected)
    }

    // MARK: - Sleep/Wake

    private func setupSleepWakeNotifications() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    @objc private func handleWake() {
        // BLE connection is likely stale after sleep — reconnect after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self else { return }
            if self.peripheral?.state != .connected {
                self.retryCount = 0
                self.connect()
            }
        }
    }

    // MARK: - Retry with exponential backoff

    private func scheduleRetry() {
        guard retryCount < maxRetries else {
            onConnectionStatusChanged?(.disconnected)
            return
        }
        retryCount += 1
        let delay = min(pow(2.0, Double(retryCount)), 30.0)
        retryTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.connect()
        }
    }

    // MARK: - Flush queued commands

    private func flushQueue() {
        guard let peripheral, let rx = rxCharacteristic,
              peripheral.state == .connected else { return }
        let queued = commandQueue
        commandQueue.removeAll()
        for command in queued {
            guard let data = command.data(using: .utf8) else { continue }
            let writeType: CBCharacteristicWriteType = rx.properties.contains(.writeWithoutResponse)
                ? .withoutResponse : .withResponse
            peripheral.writeValue(data, for: rx, type: writeType)
        }
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            connect()
        } else {
            onConnectionStatusChanged?(.disconnected)
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        if let name = peripheral.name, name.hasPrefix("MOONSIDE") {
            self.peripheral = peripheral
            peripheral.delegate = self
            central.stopScan()
            central.connect(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        retryCount = 0
        retryTimer?.invalidate()
        retryTimer = nil
        peripheral.discoverServices([Self.nusServiceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        onConnectionStatusChanged?(.disconnected)
        scheduleRetry()
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        rxCharacteristic = nil
        onConnectionStatusChanged?(.disconnected)
        // Auto-reconnect on unexpected disconnect
        if error != nil {
            scheduleRetry()
        }
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == Self.nusServiceUUID }) else {
            onConnectionStatusChanged?(.disconnected)
            return
        }
        peripheral.discoverCharacteristics([Self.nusRXCharUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let rx = service.characteristics?.first(where: { $0.uuid == Self.nusRXCharUUID }) else {
            onConnectionStatusChanged?(.disconnected)
            return
        }
        rxCharacteristic = rx
        onConnectionStatusChanged?(.connected)
        flushQueue()
    }
}
