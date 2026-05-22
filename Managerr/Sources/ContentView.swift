import SwiftUI

struct ContentView: View {
    @Environment(SettingsStore.self) private var settings
    @State private var selectedTab: TabSelection?

    var body: some View {
        TabView(selection: tabSelection) {
            Tab("Movies", systemImage: "film", value: TabSelection.movies) {
                RadarrView()
            }

            Tab("TV Shows", systemImage: "tv", value: TabSelection.tvShows) {
                SonarrView()
            }

            Tab("Music", systemImage: "music.note", value: TabSelection.music) {
                LidarrView()
            }

            Tab("Downloads", systemImage: "arrow.down.circle", value: TabSelection.downloads) {
                TransmissionView()
            }

            Tab("Settings", systemImage: "gear", value: TabSelection.settings) {
                SettingsView()
            }
        }
    }

    private var tabSelection: Binding<TabSelection?> {
        Binding(
            get: { selectedTab ?? settings.defaultTab },
            set: { selectedTab = $0 }
        )
    }
}
