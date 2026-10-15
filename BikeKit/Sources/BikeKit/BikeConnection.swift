import CoreBluetooth
import Foundation
import Observation

public struct DiscoveredBike: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public var rssi: Int
    /// Advertises Comodule's company ID — almost certainly a compatible display.
    public let isComodule: Bool
}

public struct DeviceInfo: Equatable, Sendable {
    public var name = "N/A"
    public var manufacturer = "N/A"
    public var software = "N/A"
    public var hardware = "N/A"
}

/// Latest raw frame per register ID, for the "stats for nerds" panel.
public struct RawFrame: Identifiable, Equatable, Sendable {
    public var id: String { idHex }
    public let idHex: String
    public let name: String
    public var hex: String?
}

/// One received frame, for the readings log.
public struct LoggedFrame: Identifiable, Sendable {
    public enum Source: String, Sendable { case read = "READ", notify = "NOTIFY" }
    public let id = UUID()
    public let date: Date
    public let source: Source
    public let name: String
    public let hex: String
}

@MainActor
@Observable
public final class BikeConnection: NSObject {
    public enum Phase: Equatable {
        case bluetoothUnavailable(String)
        case idle
        case scanning
        case connecting(String)
        case connected
    }

    public private(set) var phase: Phase = .idle
    public private(set) var discovered: [DiscoveredBike] = []
    public private(set) var telemetry = BikeTelemetry()
    public private(set) var deviceInfo = DeviceInfo()
    public private(set) var rawFrames: [RawFrame] = BikeConnection.watchedFrames
    /// Most recent frames first, capped at `frameLogLimit`.
    public private(set) var frameLog: [LoggedFrame] = []
    public static let frameLogLimit = 500

    /// The register IDs the original app's debug panel watched, shown as placeholders until seen.
    static let watchedFrames: [RawFrame] =
        [RegisterID.motion, .total, .ride, .settings, .power, .mystery].map { RawFrame(idHex: Data($0.bytes).hexString, name: $0.name) }
        + (1...6).map { RawFrame(idHex: Data([0x00, UInt8($0)]).hexString, name: "UNKNOWN\($0)") }
    public private(set) var lastError: String?
    public private(set) var connectedID: UUID?

    /// Peripherals to connect to as soon as a scan sees them.
    public var autoConnectIDs: Set<UUID> = []
    /// Written to the bike right after connecting ("auto apply"); nil = read the bike's own settings.
    public var settingsToApplyOnConnect: BikeSettings?

    /// Keep asking the bike for readings instead of relying only on what it pushes.
    public var pollingEnabled = false {
        didSet {
            guard pollingEnabled != oldValue else { return }
            if pollingEnabled, phase == .connected { startPolling() } else if !pollingEnabled { stopPolling() }
        }
    }

    public static let scanDuration: Duration = .seconds(5)

    @ObservationIgnored private var central: CBCentralManager!
    @ObservationIgnored private var peripherals: [UUID: CBPeripheral] = [:]
    @ObservationIgnored private var peripheral: CBPeripheral?
    @ObservationIgnored private var characteristics: [CBUUID: CBCharacteristic] = [:]
    @ObservationIgnored private var pendingServiceDiscoveries = 0
    @ObservationIgnored private var scanTask: Task<Void, Never>?
    @ObservationIgnored private var wantsScan = false
    @ObservationIgnored private var userDisconnecting = false
    @ObservationIgnored private var isDemo = false
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var pollInFlight = false

    /// Optional polling (see `pollingEnabled`).
    /// Motion and ride (speed, cadence, range) come round twice per cycle: each ~every 0.7 s.
    public static let pollInterval: Duration = .milliseconds(200)
    static let pollCycle: [RegisterID] = [.motion, .ride, .power, .motion, .ride, .total, .settings]

    public override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: Scanning

    public func scan() {
        wantsScan = true
        guard !isDemo, central.state == .poweredOn, peripheral == nil else { return }
        discovered.removeAll()
        peripherals.removeAll()
        phase = .scanning
        // Comodule displays advertise no service UUIDs, so we can't filter by service.
        central.scanForPeripherals(withServices: nil, options: nil)
        scanTask?.cancel()
        scanTask = Task { [weak self] in
            try? await Task.sleep(for: Self.scanDuration)
            guard !Task.isCancelled, let self, self.phase == .scanning else { return }
            self.stopScan()
        }
    }

    private func stopScan() {
        scanTask?.cancel()
        wantsScan = false
        if central.isScanning { central.stopScan() }
        if phase == .scanning { phase = .idle }
    }

    public var isScanning: Bool { phase == .scanning }

    // MARK: Connecting

    public func connect(_ id: UUID) {
        guard let p = peripherals[id] ?? central.retrievePeripherals(withIdentifiers: [id]).first else { return }
        stopScan()
        lastError = nil
        peripheral = p
        p.delegate = self
        phase = .connecting(p.name ?? "bike")
        central.connect(p, options: nil)
    }

    public func disconnect() {
        guard let p = peripheral else { return }
        userDisconnecting = true
        central.cancelPeripheralConnection(p)
    }

    private func resetConnectionState() {
        peripheral = nil
        connectedID = nil
        characteristics.removeAll()
        pendingServiceDiscoveries = 0
        telemetry = BikeTelemetry()
        deviceInfo = DeviceInfo()
        rawFrames = Self.watchedFrames
        frameLog.removeAll()
        stopPolling()
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
        pollInFlight = false
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            var i = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.pollInterval)
                guard let self, self.phase == .connected else { return }
                // One request at a time, so a slow link can't pile up a backlog.
                if self.pollInFlight { continue }
                self.pollInFlight = true
                self.registerAndRead(Self.pollCycle[i % Self.pollCycle.count])
                i += 1
            }
        }
    }

    public func clearLog() { frameLog.removeAll() }

    // MARK: Commands

    /// Writes settings to the bike, then reads them back so the UI shows what the bike accepted.
    public func apply(_ settings: BikeSettings) {
        guard phase == .connected else { return }
        telemetry.settings = settings
        write(settings.frame, to: BikeProtocol.register)
        registerAndRead(.settings)
    }

    private func write(_ data: Data, to uuid: CBUUID) {
        guard let p = peripheral, let c = characteristics[uuid] else { return }
        let type: CBCharacteristicWriteType = c.properties.contains(.write) ? .withResponse : .withoutResponse
        p.writeValue(data, for: c, type: type)
    }

    private func read(_ uuid: CBUUID) {
        guard let p = peripheral, let c = characteristics[uuid] else { return }
        p.readValue(for: c)
    }

    /// CoreBluetooth runs ATT requests for a peripheral strictly in order, so the
    /// read is guaranteed to see the register selected by the preceding write.
    private func registerAndRead(_ id: RegisterID) {
        write(Data(id.bytes), to: BikeProtocol.registerID)
        read(BikeProtocol.register)
    }

    private func startSession() {
        guard characteristics[BikeProtocol.register] != nil, characteristics[BikeProtocol.registerID] != nil else {
            lastError = "That device isn't a Comodule display (no metrics service)."
            disconnect()
            return
        }
        phase = .connected
        if let s = settingsToApplyOnConnect { write(s.frame, to: BikeProtocol.register) }
        if let p = peripheral, let n = characteristics[BikeProtocol.registerNotifier] {
            p.setNotifyValue(true, for: n)
        }
        for id in [RegisterID.settings, .total, .ride, .power, .motion] { registerAndRead(id) }
        for uuid in [BikeProtocol.deviceName, BikeProtocol.manufacturerName,
                     BikeProtocol.softwareRevision, BikeProtocol.hardwareRevision] { read(uuid) }
        registerAndRead(.mystery)
        if pollingEnabled { startPolling() }
    }

    /// Fake a connected bike with plausible values (launch with `-demo YES`), for UI work without hardware.
    public func loadDemo() {
        isDemo = true
        phase = .connected
        deviceInfo = DeviceInfo(name: "SUPER73", manufacturer: "COMODULE", software: "221122", hardware: "v3.2.0")
        for frame: [UInt8] in [
            [0x03, 0x00, 0x03, 0x01, 0x01, 0x02, 0, 0, 0, 0],
            [0x02, 0x01, 0x92, 0x09, 0, 0, 0, 0, 0, 0],
            [0x02, 0x02, 0, 0, 0, 0, 0x2A, 0x30, 0, 0],
            [0x02, 0x03, 0, 14, 0, 0, 0, 0, 41, 0],
            [0x04, 0x01, 0, 0, 0, 0, 0x2C, 0x01, 0, 0],
        ] { handleFrame(Data(frame)) }
    }

    private func handleFrame(_ data: Data, source: LoggedFrame.Source = .read) {
        guard data.count == BikeProtocol.frameLength else { return }
        let idHex = data.prefix(2).hexString
        let name: String
        if let i = rawFrames.firstIndex(where: { $0.idHex == idHex }) {
            rawFrames[i].hex = data.hexString
            name = rawFrames[i].name
        } else {
            name = "UNEXPECTED"
            rawFrames.append(RawFrame(idHex: idHex, name: name, hex: data.hexString))
        }
        frameLog.insert(LoggedFrame(date: .now, source: source, name: name, hex: data.hexString), at: 0)
        if frameLog.count > Self.frameLogLimit { frameLog.removeLast(frameLog.count - Self.frameLogLimit) }
        if let frame = BikeFrame(data) { telemetry.apply(frame) }
    }
}

// MARK: - CBCentralManagerDelegate

extension BikeConnection: CBCentralManagerDelegate {
    nonisolated public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        MainActor.assumeIsolated {
            switch central.state {
            case .poweredOn:
                guard !isDemo else { return }
                if phase != .connected { phase = .idle }
                scan()
            case .unauthorized:
                phase = .bluetoothUnavailable("Bluetooth permission denied. Allow Will's Bike Shop in System Settings → Privacy & Security → Bluetooth.")
            case .poweredOff:
                phase = .bluetoothUnavailable("Bluetooth is off.")
            case .unsupported:
                phase = .bluetoothUnavailable("This Mac doesn't support Bluetooth LE.")
            default:
                break
            }
        }
    }

    nonisolated public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                                           advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name
        let mfr = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        MainActor.assumeIsolated {
            guard let name, !name.isEmpty else { return }
            let id = peripheral.identifier
            peripherals[id] = peripheral
            if let i = discovered.firstIndex(where: { $0.id == id }) {
                discovered[i].rssi = RSSI.intValue
                return
            }
            let companyID = mfr.flatMap { $0.count >= 2 ? UInt16($0[$0.startIndex]) | UInt16($0[$0.startIndex + 1]) << 8 : nil }
            discovered.append(DiscoveredBike(id: id, name: name, rssi: RSSI.intValue,
                                             isComodule: companyID == BikeProtocol.comoduleCompanyID))
            if autoConnectIDs.contains(id) { connect(id) }
        }
    }

    nonisolated public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        MainActor.assumeIsolated {
            connectedID = peripheral.identifier
            peripheral.discoverServices(nil)
        }
    }

    nonisolated public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        MainActor.assumeIsolated {
            lastError = error?.localizedDescription ?? "Couldn't connect."
            resetConnectionState()
            phase = .idle
            scan()
        }
    }

    nonisolated public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        MainActor.assumeIsolated {
            if !userDisconnecting, lastError == nil, let error { lastError = "Disconnected: \(error.localizedDescription)" }
            userDisconnecting = false
            resetConnectionState()
            phase = .idle
            scan()
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BikeConnection: CBPeripheralDelegate {
    nonisolated public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        MainActor.assumeIsolated {
            let services = peripheral.services ?? []
            guard error == nil, services.contains(where: { $0.uuid == BikeProtocol.metricsService }) else {
                lastError = "That device isn't a Comodule display (no metrics service)."
                disconnect()
                return
            }
            pendingServiceDiscoveries = services.count
            for s in services { peripheral.discoverCharacteristics(nil, for: s) }
        }
    }

    nonisolated public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        MainActor.assumeIsolated {
            for c in service.characteristics ?? [] { characteristics[c.uuid] = c }
            pendingServiceDiscoveries -= 1
            if pendingServiceDiscoveries == 0 { startSession() }
        }
    }

    nonisolated public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let uuid = characteristic.uuid
        let value = characteristic.value
        MainActor.assumeIsolated {
            if uuid == BikeProtocol.register { pollInFlight = false }
            guard error == nil, let value, !value.isEmpty else { return }
            let text = String(decoding: value, as: UTF8.self)
            switch uuid {
            case BikeProtocol.register: handleFrame(value, source: .read)
            case BikeProtocol.registerNotifier: handleFrame(value, source: .notify)
            case BikeProtocol.deviceName: deviceInfo.name = text
            case BikeProtocol.manufacturerName: deviceInfo.manufacturer = text
            case BikeProtocol.softwareRevision: deviceInfo.software = text
            case BikeProtocol.hardwareRevision: deviceInfo.hardware = text
            default: break
            }
        }
    }

    nonisolated public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let error else { return }
        let message = error.localizedDescription
        MainActor.assumeIsolated {
            pollInFlight = false
            lastError = "Write failed: \(message)"
        }
    }
}
