#if DEBUG
import AppKit

/// Debug-only: `-snapshot <name>` writes PNGs of every open window to the app's temp dir and quits.
/// Lets the UI be reviewed without Screen Recording permission.
enum DebugSnapshot {
    @MainActor
    static func runIfRequested() async {
        guard let name = UserDefaults.standard.string(forKey: "snapshot") else { return }
        let delay = UserDefaults.standard.double(forKey: "snapshotDelay").nonZero ?? 2.5
        try? await Task.sleep(for: .seconds(delay))
        for (i, window) in NSApp.windows.enumerated() where window.isVisible {
            guard let view = window.contentView?.superview ?? window.contentView,
                  let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
            view.cacheDisplay(in: view.bounds, to: rep)
            let url = FileManager.default.temporaryDirectory.appending(path: "\(name)-\(i).png")
            try? rep.representation(using: .png, properties: [:])?.write(to: url)
            print("snapshot:", url.path)
        }
        NSApp.terminate(nil)
    }
}
#endif

#if DEBUG
private extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
}
#endif
