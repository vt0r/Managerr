# Managerr

A native iOS/macOS app that brings Radarr, Sonarr, Lidarr, and Transmission together in one clean dashboard.

<!-- markdownlint-disable MD033 -->
[<img src=".resources/Download_on_the_App_Store_Badge_US-UK_RGB_blk_092917.svg" alt="Download Managerr on the App Store">](https://apps.apple.com/us/app/managerr-app/id6759478095)
<!-- markdownlint-enable MD033 -->

## Features

- **Movies** — Browse your Radarr library, toggle monitoring, trigger auto or manual searches, and add new movies
- **TV Shows** — View your Sonarr series, drill into seasons and episodes, toggle monitoring per season or episode, and trigger searches
- **Music** — Explore artists and albums via Lidarr, monitor releases, and search for missing albums
- **Downloads** — Monitor active Transmission torrents with live-updating per-torrent details, peers (with optional country flags), and trackers
- **Settings** — Configure each service independently with built-in connection testing
- **Open in Browser** — Each service tab has an option to open the service's web UI in your default browser - if you find yourself using this often, please [create an issue](https://github.com/vt0r/Managerr/issues/new/choose) to let us know which feature(s) is (are) missing!

## Requirements

- iOS 17+ or macOS 14+ (runs like an iPad app on macOS)
- Xcode 15+
- One or more self-hosted services:
  - [Radarr](https://radarr.video)
  - [Sonarr](https://sonarr.tv)
  - [Lidarr](https://lidarr.audio)
  - [Transmission](https://transmissionbt.com)

You can use the app with any combination of the above services — just enable the ones you have.

## Getting Started

1. Clone the repo and open `Managerr.xcodeproj` in Xcode
2. Select your target device or simulator and run
3. Open the **Settings** tab in the app
4. Tap a service, enter its URL and credentials, then tap **Test Connection** to verify
5. Tap **Save** — the service is now live

### Service URLs

Enter the full URL including protocol and port (unless it's port `80` or `443`). Examples:

``` bash
# HTTPS: if your instance of Radarr lives behind a proxy/LB bound to port 443
https://radarr.example.com
#        Same thing, but under a URI path
https://yourreverseproxy.example.com/radarr
#        IP + URI path
https://192.168.1.10/radarr

# Regular HTTP (no TLS): connecting by IP on Radarr's default port (7878)
http://192.168.1.10:7878
```

### Credentials

| Service | Credential |
| ------- | ---------- |
| Radarr | API Key (found in `Settings → General`) |
| Sonarr | API Key (found in `Settings → General`) |
| Lidarr | API Key (found in `Settings → General`) |
| Transmission | `username:password` (leave blank if RPC auth is disabled) |

## Building from the Command Line

``` bash
# Build
xcodebuild -project Managerr.xcodeproj -scheme Managerr \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run tests
xcodebuild test -project Managerr.xcodeproj -scheme Managerr \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Project Structure

``` txt
Managerr/Sources/
├── ManagerrApp.swift          # App entry point
├── ContentView.swift          # Root TabView
├── Models/                    # Decodable API response structs
├── Services/                  # Network layer (ArrService, TransmissionService, ImageCache, …)
├── ViewModels/                # @Observable business logic
├── Views/                     # SwiftUI views and sheets
└── Utilities/                 # Formatters (bytes, speed, ETA, …)
```

No external dependencies — pure Swift, SwiftUI, and Foundation.

## Accessibility

Managerr targets full VoiceOver support and Dynamic Type compatibility at the minimum, and we will continue working to support more accessibility features as time goes on. We ask all contributors to please keep the following guidelines in mind to help us maintain (or improve!) our accessibility.

### Guidelines

**Every interactive element should be labelled.**
Buttons, toggles, and tappable cards that rely on an icon or image alone need `.accessibilityLabel("…")`. Prefer concise noun/verb phrases ("Toggle monitoring", "Play trailer").

**Decorative images should be hidden.**
Pure-decoration images (e.g. posters used as backgrounds) get `.accessibilityHidden(true)` so VoiceOver skips them.

**Compound cards should collapse into a single element.**
Grid cards use `.accessibilityElement(children: .ignore)` + `.accessibilityLabel(…)` + `.accessibilityAddTraits(.isButton)` so VoiceOver reads one cohesive description instead of individual sub-views.

**State should be expressed via label or value, not color alone.**
Monitored/unmonitored toggles, download-status badges, and similar stateful elements must include the state in their `.accessibilityLabel` or `.accessibilityValue` (e.g. `localMonitored ? "Monitored" : "Not monitored"`).

**Dynamic Type should not break layouts.**
Use semantic font styles (`.caption`, `.headline`, etc.) rather than hard-coded sizes. If a fixed size is unavoidable, pair it with `.minimumScaleFactor(0.7)` and a line-limit that allows wrapping.

**Hints are optional but welcome.**
`.accessibilityHint("…")` can clarify what a non-obvious action does. Please keep hints short and in the third person ("Opens the detail sheet").
