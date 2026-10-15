import CoreBluetooth
import Foundation

/// The Comodule Diamond Display BLE protocol, as reverse-engineered by the
/// open-source e-bike community.
///
/// Metrics live behind a "register": write a 2-byte register ID to
/// `registerID`, then read the 10-byte `register`. The same 10-byte frames are
/// also pushed on `registerNotifier`. Bytes 0–1 of every frame echo its ID.
public enum BikeProtocol {
    public static let metricsService = CBUUID(string: "00001554-1212-EFDE-1523-785FEABCD123")
    public static let registerID = CBUUID(string: "00001564-1212-EFDE-1523-785FEABCD123")
    public static let register = CBUUID(string: "0000155F-1212-EFDE-1523-785FEABCD123")
    public static let registerNotifier = CBUUID(string: "0000155E-1212-EFDE-1523-785FEABCD123")

    public static let genericAccessService = CBUUID(string: "1800")
    public static let deviceName = CBUUID(string: "2A00")

    public static let deviceInfoService = CBUUID(string: "180A")
    public static let manufacturerName = CBUUID(string: "2A29")
    public static let hardwareRevision = CBUUID(string: "2A27")
    public static let softwareRevision = CBUUID(string: "2A28")

    /// Bluetooth SIG company identifier seen in Comodule advertisements (527).
    public static let comoduleCompanyID: UInt16 = 0x020F

    public static let frameLength = 10
}

/// 2-byte register IDs.
public enum RegisterID: CaseIterable, Sendable {
    case mystery, motion, total, ride, settings, power

    public var bytes: [UInt8] {
        switch self {
        case .mystery: [0x00, 0x00]
        case .motion: [0x02, 0x01]
        case .total: [0x02, 0x02]
        case .ride: [0x02, 0x03]
        case .settings: [0x03, 0x00]
        case .power: [0x04, 0x01]
        }
    }

    public var name: String {
        switch self {
        case .mystery: "MYSTERY"
        case .motion: "MOTION"
        case .total: "TOTAL"
        case .ride: "RIDE"
        case .settings: "SETTINGS"
        case .power: "POWER"
        }
    }
}

/// Mode / assist / light — the values the app can write to the bike.
public struct BikeSettings: Equatable, Sendable {
    public static let maxMode = 7
    public static let maxAssist = 4

    public var mode: Int
    public var assist: Int
    public var light: Bool

    public init(mode: Int, assist: Int, light: Bool) {
        self.mode = min(max(mode, 0), Self.maxMode)
        self.assist = min(max(assist, 0), Self.maxAssist)
        self.light = light
    }

    public func nextMode() -> BikeSettings {
        BikeSettings(mode: mode >= Self.maxMode ? 0 : mode + 1, assist: assist, light: light)
    }

    public func nextAssist() -> BikeSettings {
        BikeSettings(mode: mode, assist: assist >= Self.maxAssist ? 0 : assist + 1, light: light)
    }

    /// Frame written to the `register` characteristic to apply settings.
    public var frame: Data {
        Data([0x00, 0xD1, light ? 0x01 : 0x00, UInt8(assist), UInt8(mode), 0, 0, 0, 0, 0])
    }
}

/// A decoded 10-byte frame.
public enum BikeFrame: Equatable, Sendable {
    case settings(BikeSettings, walk: Bool)
    /// km/h
    case motion(speed: Double)
    /// km
    case total(odometer: Double)
    /// pedal RPM, raw range in km as reported by the bike
    case ride(pedalRPM: Double, rawRange: Int)
    /// amps
    case power(chargeCurrent: Double)
    case unknown(id: [UInt8])

    public init?(_ data: Data) {
        guard data.count == BikeProtocol.frameLength else { return nil }
        let b = [UInt8](data)
        func u16(_ i: Int) -> Int { Int(b[i]) | Int(b[i + 1]) << 8 }

        switch [b[0], b[1]] {
        case RegisterID.settings.bytes:
            self = .settings(BikeSettings(mode: Int(b[5]), assist: Int(b[2]), light: b[4] == 0x01),
                             walk: b[3] == 0x00)
        case RegisterID.motion.bytes:
            // The Unity app used integer division here, truncating to whole km/h.
            self = .motion(speed: Double(u16(2)) / 100)
        case RegisterID.total.bytes:
            self = .total(odometer: Double(u16(6)) / 10)
        case RegisterID.ride.bytes:
            self = .ride(pedalRPM: Double(b[3]) * 5, rawRange: Int(b[8]))
        case RegisterID.power.bytes:
            self = .power(chargeCurrent: Double(u16(6)) / 1000)
        default:
            self = .unknown(id: [b[0], b[1]])
        }
    }
}

public extension Data {
    var hexString: String { map { String(format: "%02X", $0) }.joined(separator: " ") }
}
