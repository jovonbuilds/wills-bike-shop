import AppKit
import SwiftUI

/// The app name set in the same compressed heavy face as the speedometer digits.
struct Wordmark: View {
    var size: CGFloat = 40
    var showsIcon = true

    var body: some View {
        HStack(spacing: size * 0.28) {
            if showsIcon {
                // The real app icon, so the splash matches the Dock and Finder.
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: size * 1.6, height: size * 1.6)
            }
            Text("Will's Bike Shop")
                .font(.system(size: size, weight: .heavy).width(.compressed))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Will's Bike Shop")
    }
}

/// Shown briefly at launch.
struct SplashView: View {
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 14) {
            Wordmark(size: 64)
            Text("E-bike dashboard for Comodule displays")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .scaleEffect(appeared || reduceMotion ? 1 : 0.94)
        .opacity(appeared ? 1 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .onAppear { withAnimation(.smooth(duration: 0.6)) { appeared = true } }
    }
}
