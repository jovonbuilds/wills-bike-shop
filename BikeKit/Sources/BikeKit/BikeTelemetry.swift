import Foundation

/// User-tunable values ("modifiable base values for modders").
public struct RidePrefs: Equatable, Sendable {
    public var wheelDiameterM: Double = 0.57
    public var cellSeriesCount: Double = 13
    public var chargeCurrentThresholdA: Double = 2
    public var baseMaxRangeKm: Double = 60
    public var realMaxRangeKm: Double = 60

    public init() {}
}

/// Live metrics plus the derived values the dashboard shows. Everything is
/// stored metric; conversion happens at display time.
public struct BikeTelemetry: Equatable, Sendable {
    public var settings: BikeSettings?
    public var walk = false
    public var speedKmh: Double = 0
    public var odometerKm: Double = 0
    public var pedalRPM: Double = 0
    public var rawRange: Int = 0
    public var chargeCurrentA: Double = 0

    public init() {}

    public mutating func apply(_ frame: BikeFrame) {
        switch frame {
        case let .settings(s, walk): settings = s; self.walk = walk
        case let .motion(speed): speedKmh = speed
        case let .total(odometer): odometerKm = odometer
        case let .ride(pedal, raw): pedalRPM = pedal; rawRange = raw
        case let .power(current): chargeCurrentA = current
        case .unknown: break
        }
    }

    public func wheelRPM(_ p: RidePrefs) -> Double {
        // km/h → m/min is ×1000/60; circumference is π·d.  1000/60/π ≈ 1/0.1885
        speedKmh / p.wheelDiameterM / 0.1885
    }

    /// 0…1, from the bike's range estimate against its stock max range.
    public func batteryLevel(_ p: RidePrefs) -> Double {
        min(max(Double(rawRange) / p.baseMaxRangeKm, 0), 1)
    }

    /// Range (km) rescaled to the rider's real-world max range.
    public func rangeKm(_ p: RidePrefs) -> Double {
        min(max(Double(rawRange), 0), p.baseMaxRangeKm) / p.baseMaxRangeKm * p.realMaxRangeKm
    }

    /// Estimated pack voltage from the li-ion discharge curve. Not measured.
    public func batteryVolts(_ p: RidePrefs) -> Double {
        DischargeCurve.liIon.cellVolts(at: batteryLevel(p)) * p.cellSeriesCount
    }

    public func isCharging(_ p: RidePrefs) -> Bool { chargeCurrentA >= p.chargeCurrentThresholdA }

    /// Same fixed 41 V threshold as the original app (tuned for 13S packs).
    public func isLimp(_ p: RidePrefs) -> Bool { batteryVolts(p) < 41 }
}

/// Per-mode legal limits, indexed by mode number.
public struct ModeDescriptor: Sendable {
    public let name: String
    public let speedKmh: Double?
    public let speedMph: Double?
    public let powerW: Int?
    public let throttle: Bool

    public static let all: [ModeDescriptor] = [
        .init(name: "US CLASS 1", speedKmh: 32.2, speedMph: 20, powerW: 750, throttle: false),
        .init(name: "US CLASS 2", speedKmh: 32.2, speedMph: 20, powerW: 750, throttle: true),
        .init(name: "US CLASS 3", speedKmh: 45, speedMph: 28, powerW: 750, throttle: false),
        .init(name: "US OFF-ROAD", speedKmh: nil, speedMph: nil, powerW: nil, throttle: true),
        .init(name: "EU EPAC", speedKmh: 25, speedMph: 15.5, powerW: 250, throttle: false),
        .init(name: "EU MID", speedKmh: 35, speedMph: 22, powerW: 250, throttle: false),
        .init(name: "EU HIGH", speedKmh: 45, speedMph: 28, powerW: 850, throttle: false),
        .init(name: "EU OFF-ROAD", speedKmh: nil, speedMph: nil, powerW: nil, throttle: true),
    ]

    /// Mode the original app jumped to on long-press: the EU-legal one.
    public static let euLegalMode = 4

    public static func of(_ mode: Int) -> ModeDescriptor { all[min(max(mode, 0), all.count - 1)] }
}

/// Cubic Hermite curve matching the Unity `AnimationCurve` the original app
/// shipped for single-cell voltage vs. state of charge.
public struct DischargeCurve: Sendable {
    public struct Key: Sendable { let t, value, slope: Double }
    let keys: [Key]

    public static let liIon = DischargeCurve(keys: [
        Key(t: 0.0, value: 2.8, slope: 7.0000005),
        Key(t: 0.1, value: 3.5, slope: 6.075051),
        Key(t: 0.2, value: 3.7, slope: 0.24098521),
        Key(t: 0.8, value: 3.75, slope: 0),
        Key(t: 1.0, value: 4.2, slope: 5.130628),
    ])

    public func cellVolts(at level: Double) -> Double {
        let x = min(max(level, keys.first!.t), keys.last!.t)
        guard let i = keys.indices.dropLast().last(where: { keys[$0].t <= x }) else { return keys[0].value }
        let a = keys[i], b = keys[i + 1]
        let dt = b.t - a.t
        let s = (x - a.t) / dt
        let s2 = s * s, s3 = s2 * s
        return (2 * s3 - 3 * s2 + 1) * a.value
            + (s3 - 2 * s2 + s) * a.slope * dt
            + (-2 * s3 + 3 * s2) * b.value
            + (s3 - s2) * b.slope * dt
    }
}
