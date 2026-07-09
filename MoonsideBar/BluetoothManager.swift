import AppKit
import CoreBluetooth
import Defaults
import Foundation

final class BluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {

    // MARK: - NUS UUIDs

    static let nusServiceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    static let nusRXCharUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")

    // MARK: - Callbacks

    var onConnectionStatusChanged: ((ConnectionStatus) -> Void)?

    // MARK: - Private

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var rxCharacteristic: CBCharacteristic?
    private var retryCount = 0
    private let maxRetries = 10
    private var retryTimer: Timer?
    private var scanTimeoutTimer: Timer?
    private var connectTimeoutTimer: Timer?
    private var uuidConnectAttempts = 0
    private let maxUUIDConnectAttempts = 3
    private var commandQueue: [String] = []

    // MARK: - Init

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
        setupSleepWakeNotifications()
    }

    // MARK: - Public

    func send(_ command: String) {
        guard let peripheral, let rx = rxCharacteristic,
              peripheral.state == .connected else {
            // Queue command for when we reconnect. Compact right away so the
            // queue stays bounded while offline (last command per type wins).
            commandQueue.append(command)
            compactQueue()
            return
        }
        guard let data = command.data(using: .utf8) else { return }
        let writeType: CBCharacteristicWriteType = rx.properties.contains(.writeWithoutResponse)
            ? .withoutResponse : .withResponse
        peripheral.writeValue(data, for: rx, type: writeType)
    }

    func connect() {
        guard centralManager.state == .poweredOn else { return }

        // 1. Try saved UUID (instant reconnect, no scan needed)
        let savedUUID = Defaults[.deviceUUID]
        if let uuid = UUID(uuidString: savedUUID), !savedUUID.isEmpty,
           uuidConnectAttempts < maxUUIDConnectAttempts {
            let known = centralManager.retrievePeripherals(withIdentifiers: [uuid])
            if let p = known.first {
                uuidConnectAttempts += 1
                peripheral = p
                p.delegate = self
                centralManager.connect(p)
                onConnectionStatusChanged?(.connecting)
                // CoreBluetooth connect() never times out on its own, so a stale
                // saved UUID would be a dead end — guard the attempt and fall back
                // to a normal scan if it doesn't connect in time.
                connectTimeoutTimer?.invalidate()
                connectTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
                    guard let self, self.peripheral?.state != .connected else { return }
                    if let p = self.peripheral {
                        self.centralManager.cancelPeripheralConnection(p)
                    }
                    self.peripheral = nil
                    if self.uuidConnectAttempts >= self.maxUUIDConnectAttempts {
                        // The saved UUID looks stale — forget it. A successful
                        // connect via scan re-saves the fresh one.
                        Defaults[.deviceUUID] = ""
                    }
                    self.startScan()
                }
                return
            }
        }

        // 2. Check if already connected (e.g. by another app)
        let connected = centralManager.retrieveConnectedPeripherals(withServices: [Self.nusServiceUUID])
        if let p = connected.first(where: { $0.name?.hasPrefix("MOONSIDE") == true }) {
            peripheral = p
            p.delegate = self
            centralManager.connect(p)
            onConnectionStatusChanged?(.connecting)
            Defaults[.deviceUUID] = p.identifier.uuidString
            return
        }

        // 3. Scan
        startScan()
    }

    /// Scan without service filter — Moonside doesn't advertise NUS UUID.
    private func startScan() {
        guard centralManager.state == .poweredOn else { return }
        centralManager.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
        onConnectionStatusChanged?(.connecting)
        scanTimeoutTimer?.invalidate()
        scanTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.centralManager.stopScan()
            if self.peripheral?.state != .connected {
                self.onConnectionStatusChanged?(.disconnected)
                self.scheduleRetry()
            }
        }
    }

    func disconnect() {
        retryTimer?.invalidate()
        retryTimer = nil
        connectTimeoutTimer?.invalidate()
        connectTimeoutTimer = nil
        if let p = peripheral {
            centralManager.cancelPeripheralConnection(p)
        }
        onConnectionStatusChanged?(.disconnected)
    }

    func manualReconnect() {
        retryTimer?.invalidate()
        retryTimer = nil
        connectTimeoutTimer?.invalidate()
        connectTimeoutTimer = nil
        retryCount = 0
        uuidConnectAttempts = 0
        if let p = peripheral {
            centralManager.cancelPeripheralConnection(p)
        }
        rxCharacteristic = nil
        peripheral = nil
        onConnectionStatusChanged?(.connecting)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.connect()
        }
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
                self.uuidConnectAttempts = 0
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

    /// Collapses the offline queue to the last command per type. Lamp state is
    /// idempotent — only the final power/brightness/color/theme matters — so
    /// there is no point replaying the whole offline history after reconnect.
    private func compactQueue() {
        guard commandQueue.count > 1 else { return }
        var lastIndexByType: [String: Int] = [:]
        for (index, command) in commandQueue.enumerated() {
            lastIndexByType[Self.commandType(command)] = index
        }
        commandQueue = lastIndexByType.values.sorted().map { commandQueue[$0] }
    }

    private static func commandType(_ command: String) -> String {
        if command.hasPrefix("BRIGH") { return "brightness" }
        if command.hasPrefix("COLOR") { return "color" }
        if command.hasPrefix("THEME") { return "theme" }
        if command == BLECommand.ledOn || command == BLECommand.ledOff { return "power" }
        return command
    }

    private func flushQueue() {
        guard let peripheral, rxCharacteristic != nil,
              peripheral.state == .connected else { return }
        compactQueue()
        let queued = commandQueue
        commandQueue.removeAll()
        for (index, command) in queued.enumerated() {
            // Stagger the replayed writes slightly so the burst doesn't overrun
            // the lamp's BLE buffer (writes are mostly write-without-response).
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.06) { [weak self] in
                guard let self, let peripheral = self.peripheral, let rx = self.rxCharacteristic,
                      peripheral.state == .connected,
                      let data = command.data(using: .utf8) else { return }
                let writeType: CBCharacteristicWriteType = rx.properties.contains(.writeWithoutResponse)
                    ? .withoutResponse : .withResponse
                peripheral.writeValue(data, for: rx, type: writeType)
            }
        }
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            connect()
        case .unauthorized:
            onConnectionStatusChanged?(.unauthorized)
        default:
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
            scanTimeoutTimer?.invalidate()
            scanTimeoutTimer = nil
            self.peripheral = peripheral
            peripheral.delegate = self
            central.stopScan()
            central.connect(peripheral)
            // Save UUID for faster reconnect next time
            Defaults[.deviceUUID] = peripheral.identifier.uuidString
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        retryCount = 0
        uuidConnectAttempts = 0
        retryTimer?.invalidate()
        retryTimer = nil
        connectTimeoutTimer?.invalidate()
        connectTimeoutTimer = nil
        peripheral.discoverServices([Self.nusServiceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectTimeoutTimer?.invalidate()
        connectTimeoutTimer = nil
        onConnectionStatusChanged?(.disconnected)
        scheduleRetry()
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        rxCharacteristic = nil
        // Drop stale offline history immediately — keep only the newest command
        // per type so a long offline stretch can't build up an unbounded replay.
        compactQueue()
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
