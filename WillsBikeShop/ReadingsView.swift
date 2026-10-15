import AppKit
import SwiftUI
import BikeKit

/// Separate window with every value the bike reports, the raw registers, and a live frame log.
struct ReadingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let bike = model.bike
        let t = bike.telemetry
        let p = model.prefs
        let s = t.settings
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                GroupBox("Live readings") {
                    Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 4) {
                        row("Connection", phaseText)
                        row("Speed", "\(fmt(model.convert(t.speedKmh), 2)) \(model.speedUnit)", Explain.speed)
                        row("Wheel RPM", fmt(t.wheelRPM(p), 1), Explain.wheelRPM)
                        row("Cadence", "\(fmt(t.pedalRPM, 0)) rpm", Explain.cadence)
                        row("Odometer", "\(fmt(model.convert(t.odometerKm), 1)) \(model.distanceUnit)", Explain.odometer)
                        row("Raw range", "\(t.rawRange) km", Explain.rawRange)
                        row("Range left", "\(fmt(model.convert(t.rangeKm(p)), 1)) \(model.distanceUnit)", Explain.range)
                        row("Battery", "\(fmt(t.batteryLevel(p) * 100, 0)) %", Explain.battery)
                        row("Voltage (est.)", "\(fmt(t.batteryVolts(p), 1)) V", Explain.voltage)
                        row("Charge current", "\(fmt(t.chargeCurrentA, 3)) A", Explain.chargeCurrent)
                        row("Charging", t.isCharging(p) ? "yes" : "no", Explain.charging)
                        row("Low voltage", t.isLimp(p) ? "yes" : "no", Explain.lowVoltage)
                        row("Walk assist", t.walk ? "on" : "off", Explain.walk)
                        row("Mode", s.map { ModeDescriptor.of($0.mode).displayName } ?? "—", Explain.modes)
                        row("Assist", s.map { "\($0.assist)" } ?? "—", Explain.assist)
                        row("Headlight", s.map { $0.light ? "on" : "off" } ?? "—", Explain.headlight)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(width: 330)

                VStack(spacing: 16) {
                    GroupBox("Device") {
                        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 4) {
                            row("Name", bike.deviceInfo.name)
                            row("Manufacturer", bike.deviceInfo.manufacturer)
                            row("Software", bike.deviceInfo.software)
                            row("Hardware", bike.deviceInfo.hardware)
                            row("Identifier", bike.connectedID?.uuidString ?? "—")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    GroupBox {
                        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 4) {
                            ForEach(bike.rawFrames) { f in
                                row(f.name, f.hex ?? "\(f.idHex) -- -- -- -- -- -- -- --", Explain.register(f.name), dim: f.hex == nil)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } label: {
                        HStack(spacing: 6) {
                            Text("Registers (latest packet of each kind)")
                            InfoButton(Explain.registers)
                        }
                    }
                }
            }
            .padding()
            .fixedSize(horizontal: false, vertical: true)

            Divider()

            VStack(spacing: 6) {
                HStack {
                    Text("Frame log").font(.headline)
                    Text("\(bike.frameLog.count) of last \(BikeConnection.frameLogLimit)").foregroundStyle(.secondary)
                    InfoButton(Explain.frameSource)
                    Spacer()
                    Button("Copy") { copyLog() }.disabled(bike.frameLog.isEmpty)
                    Button("Clear") { bike.clearLog() }.disabled(bike.frameLog.isEmpty)
                }
                Table(bike.frameLog) {
                    TableColumn("Time") { Text($0.date.formatted(.dateTime.hour().minute().second().secondFraction(.fractional(3)))) }
                        .width(min: 130, ideal: 140)
                    TableColumn("Source", value: \.source.rawValue).width(60)
                    TableColumn("Register", value: \.name).width(100)
                    TableColumn("Bytes", value: \.hex)
                }
                .font(.body.monospaced())
            }
            .padding()
            .frame(minHeight: 200)
        }
        .font(.callout.monospacedDigit())
        .textSelection(.enabled)
        .frame(minWidth: 780, minHeight: 720)
    }

    private var phaseText: String {
        switch model.bike.phase {
        case .connected: "connected"
        case .connecting(let n): "connecting to \(n)"
        case .scanning: "scanning"
        case .idle: "not connected"
        case .bluetoothUnavailable(let m): m
        }
    }

    private func fmt(_ v: Double, _ digits: Int) -> String {
        v.formatted(.number.precision(.fractionLength(digits)))
    }

    private func row(_ label: String, _ value: String, _ explainer: Explainer? = nil, dim: Bool = false) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value).font(.callout.monospaced()).foregroundStyle(dim ? .tertiary : .primary)
            if let explainer { InfoButton(explainer) } else { Color.clear.gridCellUnsizedAxes([.horizontal, .vertical]) }
        }
    }

    private func copyLog() {
        let text = model.bike.frameLog.reversed().map {
            "\($0.date.ISO8601Format(.iso8601.time(includingFractionalSeconds: true)))\t\($0.source.rawValue)\t\($0.name)\t\($0.hex)"
        }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
