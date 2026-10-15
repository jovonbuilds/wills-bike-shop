import Foundation
import Observation
import SwiftUI
import BikeKit

/// App-level state: owns the BLE connection and persists everything the
/// original app kept in PlayerPrefs.
@MainActor
@Observable
final class AppModel {
    let bike = BikeConnection()

    private let defaults = UserDefaults.standard

    /// Last settings the rider chose; re-applied on connect when `autoApply` is on.
    var savedSettings: BikeSettings {
        didSet {
            defaults.set(savedSettings.mode, forKey: "mode")
            defaults.set(savedSettings.assist, forKey: "assist")
            defaults.set(savedSettings.light, forKey: "light")
            syncConnection()
        }
    }

    var metric: Bool { didSet { defaults.set(metric, forKey: "metric") } }
    var autoApply: Bool { didSet { defaults.set(autoApply, forKey: "autoApply"); syncConnection() } }
    var showBatteryLevel: Bool { didSet { defaults.set(showBatteryLevel, forKey: "showBatteryLevel") } }
    var useSystemTheme: Bool { didSet { defaults.set(useSystemTheme, forKey: "useSystemTheme") } }
    var darkTheme: Bool { didSet { defaults.set(darkTheme, forKey: "darkTheme") } }
    var showAdvanced: Bool { didSet { defaults.set(showAdvanced, forKey: "showAdvanced") } }
    var pollReadings: Bool { didSet { defaults.set(pollReadings, forKey: "pollReadings"); syncConnection() } }

    var autoConnectIDs: Set<UUID> {
        didSet {
            defaults.set(autoConnectIDs.map(\.uuidString), forKey: "autoConnectIDs")
            syncConnection()
        }
    }

    var prefs: RidePrefs {
        didSet {
            defaults.set(prefs.wheelDiameterM, forKey: "wheelDiameterM")
            defaults.set(prefs.cellSeriesCount, forKey: "cellSeriesCount")
            defaults.set(prefs.chargeCurrentThresholdA, forKey: "chargeCurrentThresholdA")
            defaults.set(prefs.baseMaxRangeKm, forKey: "baseMaxRangeKm")
            defaults.set(prefs.realMaxRangeKm, forKey: "realMaxRangeKm")
        }
    }

    init() {
        let d = UserDefaults.standard
        d.register(defaults: [
            "mode": 3, "assist": 3, "light": false, "metric": false, "autoApply": true,
            "showBatteryLevel": true, "useSystemTheme": true, "darkTheme": true, "showAdvanced": false, "pollReadings": false,
        ])
        savedSettings = BikeSettings(mode: d.integer(forKey: "mode"), assist: d.integer(forKey: "assist"),
                                     light: d.bool(forKey: "light"))
        metric = d.bool(forKey: "metric")
        autoApply = d.bool(forKey: "autoApply")
        showBatteryLevel = d.bool(forKey: "showBatteryLevel")
        useSystemTheme = d.bool(forKey: "useSystemTheme")
        darkTheme = d.bool(forKey: "darkTheme")
        showAdvanced = d.bool(forKey: "showAdvanced")
        pollReadings = d.bool(forKey: "pollReadings")
        autoConnectIDs = Set((d.stringArray(forKey: "autoConnectIDs") ?? []).compactMap(UUID.init))

        var p = RidePrefs()
        func load(_ key: String, into value: inout Double) { if let v = d.object(forKey: key) as? Double, v > 0 { value = v } }
        load("wheelDiameterM", into: &p.wheelDiameterM)
        load("cellSeriesCount", into: &p.cellSeriesCount)
        load("chargeCurrentThresholdA", into: &p.chargeCurrentThresholdA)
        load("baseMaxRangeKm", into: &p.baseMaxRangeKm)
        load("realMaxRangeKm", into: &p.realMaxRangeKm)
        prefs = p

        syncConnection()
        if d.bool(forKey: "demo") { bike.loadDemo() }
    }

    private func syncConnection() {
        bike.autoConnectIDs = autoConnectIDs
        bike.settingsToApplyOnConnect = autoApply ? savedSettings : nil
        bike.pollingEnabled = pollReadings
    }

    var colorScheme: ColorScheme? { useSystemTheme ? nil : (darkTheme ? .dark : .light) }

    // MARK: Ride controls

    /// What the dashboard shows: the bike's reported settings, else the saved ones.
    var currentSettings: BikeSettings { bike.telemetry.settings ?? savedSettings }

    func send(_ settings: BikeSettings) {
        savedSettings = settings
        bike.apply(settings)
    }

    func cycleMode() { send(currentSettings.nextMode()) }
    func cycleAssist() { send(currentSettings.nextAssist()) }
    func setAssist(_ level: Int) { send(BikeSettings(mode: currentSettings.mode, assist: level, light: currentSettings.light)) }
    func toggleLight() { var s = currentSettings; s.light.toggle(); send(s) }
    func setMode(_ mode: Int) { send(BikeSettings(mode: mode, assist: currentSettings.assist, light: currentSettings.light)) }

    // MARK: Connection

    var autoConnectCurrentBike: Bool {
        get { bike.connectedID.map(autoConnectIDs.contains) ?? false }
        set {
            guard let id = bike.connectedID else { return }
            if newValue { autoConnectIDs.insert(id) } else { autoConnectIDs.remove(id) }
        }
    }

    /// "Swap bikes": forget auto-connect for this bike so the scan list shows up.
    func swapBikes() {
        if let id = bike.connectedID { autoConnectIDs.remove(id) }
        bike.disconnect()
    }

    // MARK: Formatting

    func convert(_ km: Double) -> Double { metric ? km : km * 0.621371 }
    var speedUnit: String { metric ? "km/h" : "mph" }
    var distanceUnit: String { metric ? "km" : "mi" }

    func speedLimit(for d: ModeDescriptor) -> String {
        guard let kmh = d.speedKmh, let mph = d.speedMph else { return "MAX" }
        return metric ? "\(kmh.formatted()) km/h" : "\(mph.formatted()) mph"
    }
}
