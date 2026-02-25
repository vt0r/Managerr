import SwiftUI

@main
struct ManagerrApp: App {
    @State private var settingsStore = SettingsStore()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environment(settingsStore)
                if showSplash {
                    SplashScreenView()
                        .transition(.opacity)
                }
            }
            .task {
                try? await Task.sleep(for: .seconds(1))
                withAnimation(UIAccessibility.isReduceMotionEnabled ? nil : .easeOut(duration: 0.3)) {
                    showSplash = false
                }
            }
        }
    }
}
