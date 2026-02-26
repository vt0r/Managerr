# AGENTS.md

Shared guidance for AI coding agents working in this repository.

## What This App Does

Managerr is an iOS/macOS SwiftUI app that aggregates four media management services into a single dashboard:

- **Radarr** (movies) — default port 7878
- **Sonarr** (TV shows) — default port 8989
- **Lidarr** (music) — default port 8686
- **Transmission** (torrents) — default port 9091

## Build & Run

Open `Managerr.xcodeproj` in Xcode. There are three targets:

- **Managerr** — main app
- **ManagerrTests** — unit tests (uses Swift Testing framework, not XCTest)
- **ManagerrUITests** — UI tests

To build from the command line:

```bash
xcodebuild -project Managerr.xcodeproj -scheme Managerr -destination 'platform=iOS Simulator,name=iPhone 16' build
```

To run tests:

```bash
xcodebuild test -project Managerr.xcodeproj -scheme Managerr -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Architecture

The app uses **MVVM with SwiftUI** and the `@Observable` macro (requires iOS 17+). State is passed through the environment via `SettingsStore`.

``` txt
Managerr/Sources/
├── MediaDashboardApp.swift       # App entry point, injects SettingsStore into environment
├── ContentView.swift             # Root TabView (Movies, TV, Music, Torrents, Search, Settings)
├── Config.swift                  # Empty placeholder for future build-time config
├── Models/                       # Decodable structs matching API response shapes
├── Services/                     # Network layer (singletons)
├── ViewModels/                   # @Observable classes; own business logic and state
├── Views/                        # SwiftUI views; read state from ViewModels
└── Utilities/FormatUtils.swift   # Byte/speed/ETA/percentage formatters
```

**No external dependencies** — pure Swift/SwiftUI/Foundation only.

## Services Layer

All services are singletons accessed via `.shared`.

- **`NetworkService`** — generic `GET`/`POST` with `async/await`, 30s timeout, custom headers, returns `Decodable`
- **`ArrService`** — wraps Radarr/Sonarr/Lidarr REST APIs; uses `X-Api-Key` header auth
- **`TransmissionService`** — JSON-RPC 2.0 client; manages `X-Transmission-Session-Id` (auto-retries on 409); supports Basic auth
- **`SettingsStore`** — `@Observable`; persists `ServerConfig` per service to `UserDefaults` as JSON
- **`ImageLoader`** (`Services/ImageCache.swift`) — `actor`; 3-tier image cache: memory (LRU, 400-image cap) → disk (`Caches/ManagerrImages/`, SHA256-keyed filenames, indefinite retention) → network. Uses `byPreparingForDisplay()` for background decoding so the main thread never decodes a JPEG/PNG. Retries up to 3×; 404 is treated as final (no retry). Max 10 concurrent prefetch ops to prevent OOM on large libraries. `prefetch(urls:)` is called from Radarr/Sonarr/LidarrViewModels after data loads. The SwiftUI wrapper is `CachedAsyncImage` (`Views/CachedAsyncImage.swift`), which fades in loaded images.

## Key Models

- **`ServerConfig`** (`Models/ServerConfig.swift`) — unified config struct with `ServiceType` enum (radarr, sonarr, lidarr, transmission, tmdb)
- **`TransmissionTorrent`** (`Models/TransmissionModels.swift`) — status is an `Int` (0=Stopped, 4=Downloading, 6=Seeding); `AnyCodable` handles flexible JSON
- Radarr/Sonarr/Lidarr models are straightforward `Decodable` structs mirroring their v3/v1 API responses

## ViewModels

All use `@Observable` (not `ObservableObject`). Key patterns:

- `filteredMovies`/`filteredSeries`/etc. are computed properties applying search + sort
- Sort orders are nested enums on each ViewModel
- `LidarrViewModel` has a `viewMode` (Artists vs Albums) and fetches both concurrently with `async let`
- `TransmissionViewModel` tracks `filterStatus` (All/Downloading/Seeding/Stopped) and exposes aggregate `totalDownloadSpeed`/`totalUploadSpeed`

## Views

- **`PosterGridView`** — shared reusable card (poster image, title, subtitle, badge); used by all media service grids
- Detail views are presented as sheets (`.sheet`), not pushed navigation
- Grids use `LazyVGrid` with adaptive columns (`minimum: 110`)
- Settings are in `SettingsView` + `ServiceConfigSheet`; connection testing is done inline

## API Endpoints Used

| Service | Base path | Auth |
| ------- | --------- | ---- |
| Radarr | `/api/v3/movie`, `/api/v3/movie/lookup`, `/api/v3/command`, `/api/v3/rootfolder`, `/api/v3/qualityprofile` | `X-Api-Key` header |
| Sonarr | `/api/v3/series`, `/api/v3/series/lookup`, `/api/v3/episode` | `X-Api-Key` header |
| Lidarr | `/api/v1/artist`, `/api/v1/artist/lookup`, `/api/v1/album` | `X-Api-Key` header |
| Transmission | `/transmission/rpc` | Basic auth + session ID |

## Accessibility Standards

All SwiftUI views must meet the following requirements. These are enforced on review.

### Rules

**Every interactive element must be labelled.**
Buttons, toggles, and tappable cards that rely on an icon or image alone need `.accessibilityLabel("…")`. Prefer concise noun/verb phrases ("Toggle monitoring", "Play trailer").

**Decorative images must be hidden.**
Pure-decoration images (e.g. posters used as backgrounds) get `.accessibilityHidden(true)` so VoiceOver skips them.

**Compound cards collapse into a single element.**
`PosterGridView`-style cards use `.accessibilityElement(children: .ignore)` + `.accessibilityLabel(…)` + `.accessibilityAddTraits(.isButton)` so VoiceOver reads one cohesive description instead of individual sub-views.

**State is expressed via label or value, not colour alone.**
Monitored/unmonitored toggles, download-status badges, and similar stateful elements must include the state in their `.accessibilityLabel` or `.accessibilityValue` (e.g. `localMonitored ? "Monitored" : "Not monitored"`).

**Dynamic Type must not break layouts.**
Never hard-code font sizes with `.font(.system(size: N))` — use semantic styles (`.caption`, `.headline`, etc.). If a fixed size is unavoidable, pair it with `.minimumScaleFactor(0.7)` and a line-limit that allows wrapping.

**Hints are optional but welcome.**
`.accessibilityHint("…")` can clarify what a non-obvious action does (e.g. "Opens the detail sheet"). Keep hints short and in the third person.

### Pre-Merge Checklist

- [ ] Enable VoiceOver on a simulator and navigate every new/changed view — no unlabelled interactive elements
- [ ] Run Xcode's Accessibility Inspector (`Xcode → Open Developer Tool → Accessibility Inspector`) against the simulator
- [ ] Test with the largest Dynamic Type size (`Settings → Accessibility → Display & Text Size → Larger Text`) — no clipped or overflowing text
- [ ] Verify colour-only states have a textual/label equivalent (no red/green-only indicators)

## Expo/Web Config

The `app/+native-intent.tsx` file is an Expo Router native intent handler — it redirects all system paths to `/`. This suggests the project may be part of a larger Expo/React Native setup, though the primary codebase is native Swift.
