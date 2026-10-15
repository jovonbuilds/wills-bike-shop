import SwiftUI
import BikeKit

struct DashboardView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let t = model.bike.telemetry
        let p = model.prefs
        let mode = ModeDescriptor.of(model.currentSettings.mode)
        ScrollView {
        VStack(spacing: 22) {
            HStack(alignment: .center, spacing: 36) {
                SpeedGauge(speed: model.convert(t.speedKmh),
                           maxValue: model.metric ? 60 : 40,
                           limit: model.metric ? mode.speedKmh : mode.speedMph,
                           unit: model.speedUnit,
                           tint: mode.tint)
                    .overlay(alignment: .bottom) { StatusChips(telemetry: t, prefs: p).offset(y: 6) }
                    .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 26) {
                    BatteryReadout(telemetry: t, prefs: p)
                    AssistMeter()
                    HeadlightToggle()
                }
                .frame(width: 230)
            }
            ModePicker()
            Divider().opacity(0.6)
            HStack(spacing: 0) {
                Stat(value: t.wheelRPM(p), digits: 0, unit: "rpm", label: "Wheel", symbol: "circle.dashed", explainer: Explain.wheelRPM)
                Stat(value: t.pedalRPM, digits: 0, unit: "rpm", label: "Cadence", symbol: "arrow.trianglehead.2.clockwise.rotate.90", explainer: Explain.cadence)
                Stat(value: model.convert(t.odometerKm), digits: 0, unit: model.distanceUnit, label: "Odometer", symbol: "point.bottomleft.forward.to.point.topright.scurvepath", explainer: Explain.odometer)
            }
            if model.showAdvanced { AdvancedPanel().transition(.opacity.combined(with: .move(edge: .bottom))) }
        }
        .padding(.horizontal, 32)
        .padding(.top, 8)
        .padding(.bottom, 26)
        }
        .scrollBounceBehavior(.basedOnSize)
        .animation(.smooth, value: model.showAdvanced)
        .toolbar { toolbar }
        .navigationTitle(model.bike.deviceInfo.name == "N/A" ? "Will's Bike Shop" : model.bike.deviceInfo.name)
        .navigationSubtitle("Connected")
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            @Bindable var model = model
            Button(model.metric ? "km" : "mi") { model.metric.toggle() }
                .help(model.metric ? "Showing kilometers. Switch to miles (⌘U)" : "Showing miles. Switch to kilometers (⌘U)")
            Button {
                model.darkTheme = colorScheme != .dark
                model.useSystemTheme = false
            } label: { Label("Theme", systemImage: colorScheme == .dark ? "sun.max" : "moon") }
                .help("Switch between light and dark")
            Toggle(isOn: $model.showAdvanced) { Label("Device details", systemImage: "info.circle") }
                .help("Show device details and raw registers")
            Button { openWindow(id: "readings") } label: { Label("Readings", systemImage: "waveform.path.ecg") }
                .help("Open the live readings window (⇧⌘R)")
            Button { openWindow(id: "guide") } label: { Label("Guide", systemImage: "questionmark.circle") }
                .help("What every number and setting means")
            Button { model.swapBikes() } label: { Label("Disconnect", systemImage: "eject") }
                .help("Disconnect and choose another bike")
        }
    }
}

// MARK: - Speed gauge (the hero)

private struct SpeedGauge: View {
    let speed: Double
    let maxValue: Double
    let limit: Double?
    let unit: String
    let tint: Color

    private let start = 150.0, sweep = 240.0

    var body: some View {
        let fraction = min(max(speed / maxValue, 0), 1)
        ZStack {
            ticks
            Circle()
                .trim(from: 0, to: sweep / 360)
                .stroke(Color.primary.opacity(0.08), style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(start))
            Circle()
                .trim(from: 0, to: sweep / 360 * fraction)
                .stroke(tint.gradient, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(start))
                .shadow(color: tint.opacity(0.45), radius: 10)
                .animation(.smooth(duration: 0.35), value: fraction)
            if let limit, limit <= maxValue { limitNotch(limit) }
            VStack(spacing: -6) {
                Text(speed, format: .number.precision(.fractionLength(1)))
                    .font(.system(size: 104, weight: .heavy).width(.compressed).monospacedDigit())
                    .contentTransition(.numericText(value: speed))
                    .animation(.snappy, value: speed)
                    .help(Explain.speed.body)
                Text(unit).font(.title3.weight(.medium)).foregroundStyle(.secondary)
            }
            .padding(.bottom, 10)
            HStack(spacing: 6) {
                Text(limit.map { "Limit \($0.formatted()) \(unit)" } ?? "No speed limit")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                InfoButton(Explain.speedLimit)
            }
            .offset(y: 92)
        }
        .frame(width: 320, height: 320)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Speed \(speed.formatted(.number.precision(.fractionLength(1)))) \(unit)")
    }

    private func angle(_ value: Double) -> Angle { .degrees(start + sweep * min(max(value / maxValue, 0), 1)) }

    private var ticks: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = size.width / 2
            let step = maxValue <= 40 ? 2.0 : 2.5
            for v in stride(from: 0.0, through: maxValue, by: step) {
                let major = v.truncatingRemainder(dividingBy: 10) == 0
                let a = angle(v).radians
                let outer = r - 22, inner = outer - (major ? 10 : 5)
                var path = Path()
                path.move(to: CGPoint(x: c.x + cos(a) * inner, y: c.y + sin(a) * inner))
                path.addLine(to: CGPoint(x: c.x + cos(a) * outer, y: c.y + sin(a) * outer))
                ctx.stroke(path, with: .color(.primary.opacity(major ? 0.5 : 0.18)), lineWidth: major ? 2 : 1)
                if major {
                    let lr = inner - 14
                    ctx.draw(Text("\(Int(v))").font(.caption2.weight(.medium)).foregroundStyle(.secondary),
                             at: CGPoint(x: c.x + cos(a) * lr, y: c.y + sin(a) * lr))
                }
            }
        }
    }

    private func limitNotch(_ value: Double) -> some View {
        Capsule()
            .fill(Color.primary)
            .frame(width: 4, height: 26)
            .offset(y: -160)
            .rotationEffect(angle(value) + .degrees(90))
    }
}

private struct StatusChips: View {
    let telemetry: BikeTelemetry
    let prefs: RidePrefs

    var body: some View {
        HStack(spacing: 6) {
            if telemetry.walk { chip("Walk assist", "figure.walk", .blue).help(Explain.walk.body) }
            if telemetry.isCharging(prefs) { chip("Charging", "bolt.fill", .green).help(Explain.charging.body) }
            if telemetry.isLimp(prefs) { chip("Low voltage", "exclamationmark.triangle.fill", .red).help(Explain.lowVoltage.body) }
        }
    }

    private func chip(_ text: String, _ symbol: String, _ color: Color) -> some View {
        Label(text, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(color.opacity(0.16), in: .capsule)
            .foregroundStyle(color)
    }
}

// MARK: - Side controls

private struct BatteryReadout: View {
    @Environment(AppModel.self) private var model
    let telemetry: BikeTelemetry
    let prefs: RidePrefs

    var body: some View {
        let level = telemetry.batteryLevel(prefs)
        let color: Color = level < 0.15 ? .red : level < 0.35 ? .orange : .green
        let volts = "\(telemetry.batteryVolts(prefs).formatted(.number.precision(.fractionLength(1)))) V"
        let amps = "\(telemetry.chargeCurrentA.formatted(.number.precision(.fractionLength(2)))) A"
        let range = "\(model.convert(telemetry.rangeKm(prefs)).formatted(.number.precision(.fractionLength(0)))) \(model.distanceUnit) left"
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(model.showBatteryLevel ? "\(Int((level * 100).rounded()))%" : volts)
                    .font(.system(size: 40, weight: .bold).width(.condensed).monospacedDigit())
                    .contentTransition(.numericText())
                    .onTapGesture { model.showBatteryLevel.toggle() }
                    .help("Click to switch between battery % and estimated voltage")
                    .accessibilityAddTraits(.isButton)
                InfoButton(model.showBatteryLevel ? Explain.battery : Explain.voltage)
                Spacer()
                Image(systemName: batterySymbol(level))
                    .foregroundStyle(telemetry.isCharging(prefs) ? .green : .secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule().fill(color.gradient).frame(width: max(8, geo.size.width * level))
                }
            }
            .frame(height: 8)
            .animation(.smooth, value: level)
            HStack(spacing: 6) {
                Text(model.showBatteryLevel ? "\(range), \(volts)" : "\(amps) charge current, \(range)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                InfoButton(model.showBatteryLevel ? Explain.range : Explain.chargeCurrent)
            }
        }
    }

    private func batterySymbol(_ level: Double) -> String {
        if telemetry.isCharging(prefs) { return "battery.100percent.bolt" }
        return switch level {
        case ..<0.13: "battery.0percent"
        case ..<0.38: "battery.25percent"
        case ..<0.63: "battery.50percent"
        case ..<0.88: "battery.75percent"
        default: "battery.100percent"
        }
    }
}

private struct AssistMeter: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let assist = model.currentSettings.assist
        let tint = ModeDescriptor.of(model.currentSettings.mode).tint
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Assist").font(.headline)
                InfoButton(Explain.assist)
                Spacer()
                Text(assist == 0 ? "Off" : "Level \(assist)").foregroundStyle(.secondary).monospacedDigit()
            }
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(1...BikeSettings.maxAssist, id: \.self) { level in
                    Button { model.setAssist(level == assist ? 0 : level) } label: {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(level <= assist ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(Color.primary.opacity(0.1)))
                            .frame(height: 12 + CGFloat(level) * 7)
                    }
                    .buttonStyle(.plain)
                    .help(level == assist ? "Turn assist off" : "Set assist to level \(level)")
                }
            }
            .animation(.snappy, value: assist)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Assist level \(assist)")
    }
}

private struct HeadlightToggle: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let on = model.currentSettings.light
        let lit = colorScheme == .dark ? Color.yellow : Color(red: 0.62, green: 0.42, blue: 0.0)
        Button { model.toggleLight() } label: {
            HStack(spacing: 10) {
                Image(systemName: on ? "headlight.high.beam.fill" : "headlight.high.beam")
                    .font(.title3)
                    .symbolEffect(.bounce, value: on)
                Text(on ? "Headlight on" : "Headlight off").font(.headline)
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(on ? AnyShapeStyle(Color.yellow.opacity(0.22)) : AnyShapeStyle(Color.primary.opacity(0.06)),
                        in: .rect(cornerRadius: 12))
            .foregroundStyle(on ? lit : Color.primary)
            .shadow(color: on ? .yellow.opacity(0.35) : .clear, radius: 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(Explain.headlight.body)
        .animation(.smooth, value: on)
    }
}

// MARK: - Mode picker

private struct ModePicker: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let current = model.currentSettings.mode
        let d = ModeDescriptor.of(current)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                group("US", 0...3, current: current)
                group("EU", 4...7, current: current)
            }
            HStack(spacing: 6) {
                Text(summary(d))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
                InfoButton(Explain.modes)
            }
        }
        .contextMenu {
            Button("Switch to EU EPAC (road legal)") { model.setMode(ModeDescriptor.euLegalMode) }
        }
    }

    private func group(_ title: String, _ range: ClosedRange<Int>, current: Int) -> some View {
        HStack(spacing: 0) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 30)
            ForEach(Array(range), id: \.self) { i in
                segment(i, selected: i == current)
            }
        }
        .padding(4)
        .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: 12))
    }

    private func segment(_ i: Int, selected: Bool) -> some View {
        let d = ModeDescriptor.of(i)
        return Button { model.setMode(i) } label: {
            VStack(spacing: 2) {
                HStack(spacing: 3) {
                    Text(d.shortName).font(.callout.weight(.semibold))
                    if d.throttle { Image(systemName: "hand.raised.fingers.spread.fill").font(.caption2).opacity(0.7) }
                }
                Text(model.speedLimit(for: d) == "MAX" ? "No limit" : model.speedLimit(for: d))
                    .font(.caption)
                    .opacity(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(selected ? AnyShapeStyle(d.tint.gradient) : AnyShapeStyle(Color.clear), in: .rect(cornerRadius: 9))
            .foregroundStyle(selected ? Color.black : Color.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Mode \(i): \(d.name)")
        .animation(.snappy, value: selected)
    }

    private func summary(_ d: ModeDescriptor) -> String {
        let power = d.powerW.map { "\($0) W motor" } ?? "unrestricted motor"
        let speed = model.speedLimit(for: d) == "MAX" ? "no speed limit" : "limited to \(model.speedLimit(for: d))"
        return "\(d.displayName): \(speed), \(power), throttle \(d.throttle ? "on" : "off")"
    }
}

// MARK: - Stats

private struct Stat: View {
    let value: Double
    let digits: Int
    let unit: String
    let label: String
    let symbol: String
    let explainer: Explainer

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Label(label, systemImage: symbol).font(.callout).foregroundStyle(.secondary)
                InfoButton(explainer)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value, format: .number.precision(.fractionLength(digits)))
                    .font(.system(size: 30, weight: .semibold).width(.condensed).monospacedDigit())
                    .contentTransition(.numericText(value: value))
                Text(unit).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Device details ("stats for nerds")

private struct AdvancedPanel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let info = model.bike.deviceInfo
        HStack(alignment: .top, spacing: 32) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                row("Display", info.name)
                row("Maker", info.manufacturer)
                row("Software", info.software)
                row("Hardware", info.hardware)
            }
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                ForEach(model.bike.rawFrames) { f in
                    row(f.name.capitalized, f.hex ?? "\(f.idHex) -- -- -- -- -- -- -- --", mono: true, dim: f.hex == nil)
                }
            }
            Spacer(minLength: 0)
        }
        .font(.caption)
        .textSelection(.enabled)
        .padding(14)
        .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 12))
    }

    private func row(_ label: String, _ value: String, mono: Bool = false, dim: Bool = false) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value).font(mono ? .caption.monospaced() : .caption).foregroundStyle(dim ? .tertiary : .primary)
        }
    }
}

// MARK: - Mode presentation

extension ModeDescriptor {
    /// Amber for US classes, blue for EU classes, red-orange for unrestricted off-road.
    var tint: Color {
        if speedKmh == nil { return Color(red: 1.0, green: 0.36, blue: 0.22) }
        return name.hasPrefix("EU") ? Color(red: 0.30, green: 0.58, blue: 1.0) : Color(red: 1.0, green: 0.70, blue: 0.13)
    }

    var displayName: String { "\(name.hasPrefix("EU") ? "EU" : "US") \(shortName)" }

    var shortName: String {
        switch name {
        case "US CLASS 1": "Class 1"
        case "US CLASS 2": "Class 2"
        case "US CLASS 3": "Class 3"
        case "EU EPAC": "EPAC"
        case "EU MID": "Mid"
        case "EU HIGH": "High"
        default: "Off-road"
        }
    }
}
