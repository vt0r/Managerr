# Managerr

A native iOS/macOS app that brings Radarr, Sonarr, Lidarr, and Transmission together in one clean dashboard.

## Features (by tab name)

- **Movies** — Browse your Radarr library, toggle monitoring, trigger searches, and add new movies
- **TV Shows** — View your Sonarr series, drill into seasons and episodes, and manage monitoring
- **Music** — Explore artists and albums via Lidarr, monitor releases, and search for missing albums
- **Downloads** — Monitor active Transmission torrents with per-torrent details, peers, and trackers
- **Search** — Search across all three Arr services at once and add new content directly from results
- **Settings** — Configure each service independently with built-in connection testing

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

Enter the full URL including protocol and port, for example:

``` txt
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

```bash
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

## Notes

- All settings are stored locally on-device via `UserDefaults`
- Poster images are cached to disk (`Caches/ManagerrImages/`) to reduce network traffic
- Transmission uses JSON-RPC 2.0 with automatic session-ID negotiation
