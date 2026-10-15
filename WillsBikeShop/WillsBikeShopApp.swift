import SwiftUI
import BikeKit

@main
struct WillsBikeShopApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        Window("Will's Bike Shop", id: "main") {
            RootView()
                .environment(model)
                .preferredColorScheme(model.colorScheme)
                .frame(minWidth: 760, minHeight: 600)
        }
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandMenu("Bike") {
                Button("Next Mode") { model.cycleMode() }.keyboardShortcut("m", modifiers: [])
                Button("Next Assist Level") { model.cycleAssist() }.keyboardShortcut("a", modifiers: [])
                Button("Toggle Headlight") { model.toggleLight() }.keyboardShortcut("l", modifiers: [])
                Button("Switch to EU EPAC") { model.setMode(ModeDescriptor.euLegalMode) }.keyboardShortcut("e", modifiers: [])
                Divider()
                Button(model.metric ? "Use Miles" : "Use Kilometers") { model.metric.toggle() }.keyboardShortcut("u", modifiers: [.command])
                Button("Disconnect") { model.swapBikes() }.keyboardShortcut("d", modifiers: [.command, .shift])
            }
        }

        Window("Guide", id: "guide") {
            GuideView()
                .preferredColorScheme(model.colorScheme)
        }
        .commands { HelpCommands() }

        Window("Bike Readings", id: "readings") {
            ReadingsView()
                .environment(model)
                .preferredColorScheme(model.colorScheme)
        }
        .keyboardShortcut("r", modifiers: [.command, .shift])

        Settings {
            SettingsView()
                .environment(model)
                .preferredColorScheme(model.colorScheme)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var awake: NSObjectProtocol?
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @State private var showSplash = true

    var body: some View {
        Group {
            if model.bike.phase == .connected {
                DashboardView().transition(.opacity)
            } else {
                ScanView().transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if showSplash { SplashView().transition(.opacity.combined(with: .scale(scale: 1.04))) }
        }
        .task {
            // Long enough to read the name while Bluetooth powers up; short enough not to be in the way.
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation(.smooth(duration: 0.5)) { showSplash = false }
        }
        .containerBackground(.thickMaterial, for: .window)
        .animation(.smooth, value: model.bike.phase == .connected)
        // The original app kept the screen on while riding; do the same while connected.
        .onChange(of: model.bike.phase == .connected, initial: true) { _, connected in
            if connected, awake == nil {
                awake = ProcessInfo.processInfo.beginActivity(options: [.idleDisplaySleepDisabled, .userInitiated],
                                                              reason: "Showing live bike dashboard")
            } else if !connected, let token = awake {
                ProcessInfo.processInfo.endActivity(token)
                awake = nil
            }
        }
        #if DEBUG
        .task {
            if UserDefaults.standard.bool(forKey: "openReadings") { openWindow(id: "readings") }
            if UserDefaults.standard.bool(forKey: "openGuide") { openWindow(id: "guide") }
            if UserDefaults.standard.bool(forKey: "openSettingsWindow") { openSettings() }
            await DebugSnapshot.runIfRequested()
        }
        #endif
    }
}

private struct HelpCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button("Will's Bike Shop Guide") { openWindow(id: "guide") }
                .keyboardShortcut("?", modifiers: .command)
        }
    }
}
