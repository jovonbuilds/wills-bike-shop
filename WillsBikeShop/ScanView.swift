import SwiftUI
import BikeKit

struct ScanView: View {
    @Environment(AppModel.self) private var model
    @State private var showOthers = false

    private var bikes: [DiscoveredBike] { model.bike.discovered.filter(\.isComodule).sorted { $0.rssi > $1.rssi } }
    private var others: [DiscoveredBike] { model.bike.discovered.filter { !$0.isComodule }.sorted { $0.rssi > $1.rssi } }

    var body: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 0)
            Wordmark(size: 40, showsIcon: false)
            Radar(active: model.bike.isScanning || isConnecting)

            VStack(spacing: 8) {
                Text(title).font(.system(size: 28, weight: .bold))
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }

            if let error = model.bike.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.orange.opacity(0.12), in: .capsule)
            }

            if !isConnecting, !isUnavailable {
                results
                if !model.bike.isScanning {
                    Button("Scan again") { model.bike.scan() }
                        .controlSize(.large)
                        .keyboardShortcut("r", modifiers: .command)
                }
            }
            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 24)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .animation(.smooth, value: model.bike.discovered.count)
        .navigationTitle("Will's Bike Shop")
    }

    private var isConnecting: Bool { if case .connecting = model.bike.phase { true } else { false } }
    private var isUnavailable: Bool { if case .bluetoothUnavailable = model.bike.phase { true } else { false } }

    private var title: String {
        switch model.bike.phase {
        case .connecting(let name): "Connecting to \(name)"
        case .bluetoothUnavailable: "Bluetooth is unavailable"
        default: bikes.isEmpty ? "Find your bike" : "Choose your bike"
        }
    }

    private var subtitle: String {
        switch model.bike.phase {
        case .bluetoothUnavailable(let message): message
        case .connecting: "Reading the display's settings and live data."
        default:
            model.autoConnectIDs.isEmpty
                ? "Turn on the bike's display and keep it within a few meters of this Mac."
                : "Turn on the bike's display. Bikes set to auto-connect open straight to the dashboard."
        }
    }

    @ViewBuilder private var results: some View {
        if !bikes.isEmpty || !others.isEmpty {
            VStack(spacing: 0) {
                ForEach(bikes) { row($0) }
                if !others.isEmpty {
                    if !bikes.isEmpty { Divider().padding(.leading, 52) }
                    DisclosureGroup(isExpanded: $showOthers) {
                        ForEach(others) { row($0) }
                    } label: {
                        Text(bikes.isEmpty
                             ? "No bike displays found. Show \(others.count) other nearby devices"
                             : "Show \(others.count) other nearby devices")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                }
            }
            .background(.regularMaterial, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.08)))
        }
    }

    private func row(_ bike: DiscoveredBike) -> some View {
        Button { model.bike.connect(bike.id) } label: {
            HStack(spacing: 14) {
                Image(systemName: bike.isComodule ? "bicycle" : "dot.radiowaves.left.and.right")
                    .font(.title3)
                    .frame(width: 26)
                    .foregroundStyle(bike.isComodule ? Color.primary : .secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(bike.name).font(.headline)
                    Text(bike.isComodule ? "Comodule display" : "Bluetooth device").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "cellularbars", variableValue: signal(bike.rssi))
                    .foregroundStyle(.secondary)
                    .help("\(bike.rssi) dBm")
                Text("Connect").font(.callout.weight(.medium)).foregroundStyle(.tint)
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func signal(_ rssi: Int) -> Double { min(max(Double(rssi + 95) / 45, 0), 1) }
}

/// Bike glyph inside concentric rings; the rings pulse only while scanning or connecting.
private struct Radar: View {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: !active || reduceMotion)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.4) / 2.4
            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.10 - Double(i) * 0.025), lineWidth: 1)
                        .frame(width: 70 + CGFloat(i) * 46)
                }
                if active && !reduceMotion {
                    Circle()
                        .strokeBorder(Color.accentColor.opacity(0.5 * (1 - phase)), lineWidth: 2)
                        .frame(width: 70 + 92 * phase)
                }
                Image(systemName: "bicycle")
                    .font(.system(size: 30, weight: .medium))
                    .frame(width: 70, height: 70)
                    .background(.regularMaterial, in: .circle)
            }
        }
        .frame(width: 170, height: 170)
        .accessibilityHidden(true)
    }
}
