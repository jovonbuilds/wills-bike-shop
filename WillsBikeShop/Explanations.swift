import SwiftUI

/// One plain-language explanation, shown in info popovers, Settings and the Guide window.
struct Explainer: Identifiable, Hashable {
    let id: String
    let title: String
    let body: String
}

/// Every number, reading and setting in the app, explained once and reused everywhere.
enum Explain {
    // MARK: Readings

    static let speed = Explainer(id: "speed", title: "Speed",
        body: "How fast you're going, as reported by the bike's display. Shown in km/h or mph; switch with the km/mi button.")
    static let speedLimit = Explainer(id: "speedLimit", title: "Speed limit marker",
        body: "The white mark on the gauge is the top speed the motor will assist to in the current mode. Above it you're on your own legs. Off-road modes have no limit, so there's no marker.")
    static let battery = Explainer(id: "battery", title: "Battery %",
        body: "An estimate, not a direct battery measurement. The bike reports how far it thinks you can go; that is compared with the bike's stock range (Settings → Base max range). Below 35% the bar turns orange, below 15% red.")
    static let range = Explainer(id: "range", title: "Range left",
        body: "How far you can still ride. It's the bike's own range estimate, rescaled to your real max range in Settings, so it accounts for an older battery, your riding style or a bigger battery.")
    static let voltage = Explainer(id: "voltage", title: "Battery voltage (estimated)",
        body: "Estimated, not measured. The app converts battery % into a per-cell voltage using a typical lithium-ion discharge curve, then multiplies by the series cell count in Settings. Click the battery reading to switch between % and volts.")
    static let chargeCurrent = Explainer(id: "chargeCurrent", title: "Charge current",
        body: "Current flowing into the battery, in amps. Small values can appear while riding (for example when braking or coasting). Above the min charge current in Settings, the dashboard shows Charging.")
    static let charging = Explainer(id: "charging", title: "Charging",
        body: "Shown when the charge current is above the min charge current in Settings. This is a display hint only; it doesn't change anything on the bike.")
    static let lowVoltage = Explainer(id: "lowVoltage", title: "Low voltage",
        body: "Shown when the estimated pack voltage drops below 41 V. Many bikes cut motor power at this point to protect the battery (limp mode). The 41 V threshold suits 13-cell (48 V) batteries.")
    static let walk = Explainer(id: "walk", title: "Walk assist",
        body: "The bike reports walk mode is on: the motor gently pushes the bike at walking pace while you walk beside it.")
    static let wheelRPM = Explainer(id: "wheelRPM", title: "Wheel RPM",
        body: "Wheel revolutions per minute, calculated from your speed and the wheel diameter in Settings. If it looks off, check the wheel diameter.")
    static let cadence = Explainer(id: "cadence", title: "Cadence",
        body: "How fast you're pedaling, in crank revolutions per minute. The bike reports it in steps of 5 rpm. 0 means you're not pedaling.")
    static let odometer = Explainer(id: "odometer", title: "Odometer",
        body: "Total distance the bike has recorded over its lifetime, read from the display.")
    static let rawRange = Explainer(id: "rawRange", title: "Raw range",
        body: "The bike's own range estimate in km, before any adjustment. Battery % and Range left are both calculated from this.")

    // MARK: Controls

    static let assist = Explainer(id: "assist", title: "Assist level",
        body: "How much the motor helps while you pedal. 0 is off, 4 is the most help. Higher levels feel stronger and use the battery faster. Click a bar to choose a level; click the top lit bar again to turn assist off. Shortcut: A.")
    static let headlight = Explainer(id: "headlight", title: "Headlight",
        body: "Turns the bike's headlight on or off. Shortcut: L.")
    static let modes = Explainer(id: "modes", title: "Riding modes",
        body: """
        A mode sets the motor's top assisted speed, its power and whether the throttle works. What's legal depends on where you ride.

        US Class 1: pedal assist to 20 mph (32 km/h), no throttle.
        US Class 2: like Class 1, plus a throttle.
        US Class 3: pedal assist to 28 mph (45 km/h), no throttle.
        EU EPAC: 25 km/h (15.5 mph), 250 W. The standard road-legal e-bike class in Europe.
        EU Mid: 35 km/h (22 mph), 250 W.
        EU High: 45 km/h (28 mph), 850 W. Usually needs registration and insurance.
        Off-road (US or EU): no speed or power limit, throttle on. For private land only.

        Shortcuts: M for the next mode, E to jump to EU EPAC. Right-click the modes for the same option.
        """)

    // MARK: Settings

    static let wheelDiameter = Explainer(id: "wheelDiameter", title: "Wheel diameter",
        body: "Outer diameter of the rear tire, in meters. Only used for the wheel RPM reading. Default 0.57 m (about 22.4 in).")
    static let cellCount = Explainer(id: "cellCount", title: "Series cell count",
        body: "How many lithium-ion cells are wired in series in your battery. 13 is a 48 V battery, 14 is 52 V. Only used for the voltage estimate. Default 13.")
    static let minCharge = Explainer(id: "minCharge", title: "Min charge current",
        body: "Above this current, in amps, the dashboard shows Charging. Raise it if Charging flickers on while you ride. Default 2 A.")
    static let baseRange = Explainer(id: "baseRange", title: "Base max range",
        body: "Your bike's factory range on a full battery, in km. Battery % compares the bike's live range estimate with this number. Default 60 km.")
    static let realRange = Explainer(id: "realRange", title: "Real max range",
        body: "How far you actually get on a full battery, in km. Range left is scaled to this, so set it from experience. Raise it for a dual or bigger battery; lower it for a worn battery or hilly riding. Default 60 km.")
    static let autoApply = Explainer(id: "autoApply", title: "Auto-apply my settings",
        body: "When on, your last mode, assist level and headlight choice are sent to the bike as soon as it connects. Useful on EU bikes that reset to the legal mode at every start. When off, the app shows whatever the bike is already set to.")
    static let autoConnect = Explainer(id: "autoConnect", title: "Auto-connect",
        body: "Connect to this bike automatically whenever the app finds it, skipping the bike list. Disconnecting with the eject button turns this off for that bike.")
    static let polling = Explainer(id: "polling", title: "Keep asking the bike for readings",
        body: "Off: readings are read once when the bike connects, then update whenever the bike sends a change. On: the app also asks for every reading several times a second. Turn it on if speed or cadence look frozen while riding. Default off.")
    static let units = Explainer(id: "units", title: "Units",
        body: "Show speed and distance in kilometers or miles. The range settings are always entered in km.")
    static let theme = Explainer(id: "theme", title: "Appearance",
        body: "Follow your Mac's light or dark setting, or pick one. The sun/moon button in the toolbar switches it directly.")
    static let details = Explainer(id: "details", title: "Device details",
        body: "Shows the display's name, maker and firmware, plus the raw data the bike sends. Mostly useful for troubleshooting.")

    // MARK: Raw data

    static let frameSource = Explainer(id: "frameSource", title: "Read vs Notify",
        body: "READ means the app asked the bike for a value: once at connect, or continuously if \"Keep asking the bike for readings\" is on in Settings. NOTIFY means the bike sent the value on its own when it changed.")
    static let registers = Explainer(id: "registers", title: "Registers",
        body: "The bike sends data in 10-byte packets; the first two bytes say which kind. Byte positions here count from 1. Grey rows haven't been received yet. Unknown rows are kinds nobody has decoded; they're shown so you can spot changes.")

    /// Byte map per register, for the raw-data rows.
    static func register(_ name: String) -> Explainer {
        let body: String = switch name {
        case "MOTION": "Speed. Bytes 3–4 are the speed in hundredths of a km/h (low byte first)."
        case "TOTAL": "Odometer. Bytes 7–8 are the total distance in tenths of a km (low byte first)."
        case "RIDE": "Ride data. Byte 4 is cadence ÷ 5. Byte 9 is the bike's range estimate in km."
        case "SETTINGS": "Current settings. Byte 3 is assist level, byte 4 is walk mode (00 = on), byte 5 is the headlight (01 = on), byte 6 is the mode number."
        case "POWER": "Power. Bytes 7–8 are the charge current in milliamps (low byte first)."
        case "MYSTERY": "Register 00 00. Read at startup like the original app did; its meaning isn't known."
        default: "Not decoded yet. Shown so you can see if it changes while you ride, charge or switch settings."
        }
        return Explainer(id: "register-\(name)", title: name.capitalized, body: body)
    }

    static let guide: [(String, [Explainer])] = [
        ("Ride readings", [speed, speedLimit, battery, range, voltage, chargeCurrent, wheelRPM, cadence, odometer]),
        ("Indicators", [charging, lowVoltage, walk]),
        ("Controls", [modes, assist, headlight]),
        ("Settings", [wheelDiameter, cellCount, minCharge, baseRange, realRange, autoApply, autoConnect, polling, units, theme, details]),
        ("Raw data", [rawRange, registers, frameSource]),
    ]
}

/// Small ⓘ button that explains the thing next to it.
struct InfoButton: View {
    let explainer: Explainer
    @State private var shown = false

    init(_ explainer: Explainer) { self.explainer = explainer }

    var body: some View {
        Button { shown.toggle() } label: {
            Image(systemName: "info.circle")
                .font(.callout)
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(explainer.body)
        .accessibilityLabel("About \(explainer.title)")
        .popover(isPresented: $shown, arrowEdge: .bottom) {
            ExplainerText(explainer: explainer)
                .padding(16)
                .frame(width: 300)
        }
    }
}

struct ExplainerText: View {
    let explainer: Explainer

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(explainer.title).font(.headline)
            Text(explainer.body)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Help → Will's Bike Shop Guide.
struct GuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("How to read your dashboard").font(.largeTitle.weight(.bold))
                    Text("What every number, control and setting means. Hover over anything in the app for a quick reminder, or click an ⓘ for details.")
                        .foregroundStyle(.secondary)
                }
                ForEach(Explain.guide, id: \.0) { section, items in
                    VStack(alignment: .leading, spacing: 16) {
                        Text(section).font(.title2.weight(.semibold))
                        ForEach(items) { ExplainerText(explainer: $0) }
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: 620, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .frame(minWidth: 520, minHeight: 560)
        .textSelection(.enabled)
    }
}
