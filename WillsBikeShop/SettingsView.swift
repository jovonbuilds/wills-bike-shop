import SwiftUI
import BikeKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                number(Explain.wheelDiameter, value: $model.prefs.wheelDiameterM, unit: "m")
                number(Explain.cellCount, value: $model.prefs.cellSeriesCount, unit: "cells")
                number(Explain.minCharge, value: $model.prefs.chargeCurrentThresholdA, unit: "A")
                number(Explain.baseRange, value: $model.prefs.baseMaxRangeKm, unit: "km")
                number(Explain.realRange, value: $model.prefs.realMaxRangeKm, unit: "km")
                Button("Restore defaults") { model.prefs = RidePrefs() }
                    .disabled(model.prefs == RidePrefs())
            } header: {
                Text("Your bike")
            } footer: {
                Text("These only change how readings are calculated in this app. Nothing here is sent to the bike.")
                    .foregroundStyle(.secondary)
            }

            Section("Connection") {
                toggle(Explain.autoApply, isOn: $model.autoApply)
                toggle(Explain.autoConnect, isOn: $model.autoConnectCurrentBike)
                    .disabled(model.bike.connectedID == nil)
                toggle(Explain.polling, isOn: $model.pollReadings)
                if !model.autoConnectIDs.isEmpty {
                    Button("Forget all auto-connect bikes (\(model.autoConnectIDs.count))") { model.autoConnectIDs.removeAll() }
                }
            }

            Section("Display") {
                toggle(Explain.units, title: "Metric units (km)", isOn: $model.metric)
                toggle(Explain.theme, title: "Match Mac appearance", isOn: $model.useSystemTheme)
                if !model.useSystemTheme {
                    Picker("Theme", selection: $model.darkTheme) {
                        Text("Light").tag(false)
                        Text("Dark").tag(true)
                    }
                    .pickerStyle(.segmented)
                }
                toggle(Explain.details, title: "Show device details", isOn: $model.showAdvanced)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .frame(minHeight: 560)
    }

    private func label(_ e: Explainer, title: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title ?? e.title)
            Text(e.body)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func toggle(_ e: Explainer, title: String? = nil, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) { label(e, title: title) }
    }

    private func number(_ e: Explainer, value: Binding<Double>, unit: String) -> some View {
        LabeledContent {
            HStack(spacing: 4) {
                TextField(e.title, value: Binding(get: { value.wrappedValue },
                                                  set: { if $0 > 0 { value.wrappedValue = $0 } }),
                          format: .number)
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 70)
                Text(unit).foregroundStyle(.secondary).frame(width: 34, alignment: .leading)
            }
        } label: {
            label(e)
        }
    }
}
