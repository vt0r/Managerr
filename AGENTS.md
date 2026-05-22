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

- The app uses **MVVM with SwiftUI** and the `@Observable` macro (requires iOS 17+). State is passed through the environment via `SettingsStore`.
- Keep views thin; move logic into view models or dedicated services
- Never put networking code directly in a view

``` txt
Managerr/Sources/
├── ManagerrApp.swift             # App entry point, injects SettingsStore into environment
├── ContentView.swift             # Root TabView (Movies, TV Shows, Music, Downloads, Settings)
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

- **`ServerConfig`** (`Models/ServerConfig.swift`) — unified config struct with `ServiceType` enum (radarr, sonarr, lidarr, transmission); also defines `TabSelection` enum
- **`TransmissionTorrent`** (`Models/TransmissionModels.swift`) — status is an `Int` (0=Stopped, 4=Downloading, 6=Seeding); `AnyCodable` handles flexible JSON
- **`ArrQueueRecord`** (`Models/QueueModels.swift`) — unified queue item for all three *arrs; `protocol` is decoded via `CodingKeys` to `downloadProtocol`; embeds optional `ArrQueueMovie/Series/Episode/Artist/Album` for display title construction; all structs are `nonisolated` to satisfy `Sendable` constraints
- **`ArrTag`** (`Models/RadarrModels.swift`) — shared `nonisolated struct` (`id: Int`, `label: String`) used by all three *arrs for tag management in edit sheets
- **`LidarrAlbumRelease`** (`Models/LidarrModels.swift`) — release record embedded in `LidarrAlbum`; fields: `id`, `title`, `mediumCount`, `trackCount`, `releaseDate`, `status`, `monitored`
- Radarr/Sonarr/Lidarr models are straightforward `Decodable` structs mirroring their v3/v1 API responses; `RadarrMovie`, `SonarrSeries`, and `LidarrArtist` include `tags: [Int]?`; `SonarrSeries` adds `monitorNewItems: String?` and `seasonFolder: Bool?`; `LidarrArtist` adds `monitorNewItems: String?`; `LidarrAlbum` adds `anyReleaseOk: Bool?` and `releases: [LidarrAlbumRelease]?`

## ViewModels

All use `@Observable` (not `ObservableObject`). Key patterns:

- `filteredMovies`/`filteredSeries`/etc. are computed properties applying search + sort
- Sort orders are nested enums on each ViewModel
- `LidarrViewModel` has a `viewMode` (Artists vs Albums) and fetches both concurrently with `async let`
- `TransmissionViewModel` tracks `filterStatus` (All/Downloading/Seeding/Stopped), `sortOption` (Name/DateAdded/Size/Progress/Ratio/Speed), and `sortAscending`. Exposes aggregate `totalDownloadSpeed`/`totalUploadSpeed`. `peerCountries: [String: String]` caches IP → country code lookups (batched at 10/s via `api.country.is`). `detailedTorrent` is populated by `fetchTorrentDetail` which is called once on sheet open then polled every 5 seconds.
- `QueueViewModel` fetches all three *arr queues in parallel via `withTaskGroup`, exposes `filteredItems` (computed, driven by `serviceFilter: ServiceType?` and `statusFilter: QueueStatusFilter`), and auto-polls every 30 seconds via a `while !Task.isCancelled` loop in `.task`. `QueueStatusFilter` is an enum: All / Active / Warning / Error. An optional `limitToService: ServiceType?` property scopes fetches to a single service (used when launched as a per-*arr queue sheet); when set, the service filter picker is hidden and `isFiltered` excludes service from its calculation.

## Views

- **`PosterGridView`** — shared reusable card (poster image, title, subtitle, badge); used by all media service grids
- Detail views are presented as sheets (`.sheet`), not pushed navigation
- Grids use `LazyVGrid` with adaptive columns (`minimum: 110`)
- Settings are in `SettingsView` + `ServiceConfigSheet`; connection testing is done inline
- **`ManualSearchView`** — generic sheet for browsing and grabbing indexer releases; used by movie, season, episode, and album detail sheets
- **`SeasonDetailSheet`** — episode list for a single season; supports per-episode and per-season monitored toggling, file deletion, and manual/auto search
- **`QueueView`** — reusable queue sheet; flat list of *arr queue items sorted by urgency; launched as a per-service sheet from each *arr view's `•••` menu (Movies/TV Shows/Music) via `QueueView(service: .radarr/.sonarr/.lidarr)`; filter menu (service + status) mirrors the sort-menu pattern from Radarr/Sonarr views (service picker hidden in single-service mode); rows open `QueueDetailSheet` on tap; trailing swipe removes, leading swipe Force Grabs (delayed items only); `ServiceType.abbreviation` and `ServiceType.badgeColor` extensions live here at internal scope (shared with `QueueDetailSheet`)
- **`QueueDetailSheet`** — download detail sheet; colored header strip using the service's badge color; progress section with size breakdown, percentage, ETA, and estimated completion as a relative `Text(date, style: .relative)`; download details section (protocol, client, indexer, full selectable release name); status messages panel shown only when warnings/errors are present; Force Grab and Remove actions at the bottom
- **`MovieEditSheet`** — edit sheet for a Radarr movie; fields: Monitored toggle, Quality Profile picker, Minimum Availability picker (tba/announced/inCinemas/released/preDB), Root Folder picker (navigationLink style), Tags multi-select; fetches profiles/folders/tags on appear; saves via JSON patch PUT
- **`SeriesEditSheet`** — edit sheet for a Sonarr series; fields: Monitored toggle, Monitor New Seasons picker (all/none), Quality Profile picker, Series Type picker (standard/daily/anime), Use Season Folders toggle, Root Folder picker, Tags multi-select
- **`ArtistEditSheet`** — edit sheet for a Lidarr artist; fields: Monitored toggle, Monitor New Albums picker (all/new/none), Quality Profile picker, Metadata Profile picker, Root Folder picker, Tags multi-select
- **`AlbumEditSheet`** — edit sheet for a Lidarr album; fetches full album detail from `/api/v1/album/{id}` to get releases array; fields: Monitored toggle, Automatically Switch Release toggle (with subtitle), Release picker (disabled when auto-switch on)
- Edit sheets are presented from the leading toolbar button (pencil icon) of each detail sheet; on save they call an `onSaved: () -> Void` callback that triggers a silent background refresh of the parent view model
- **JSON patch pattern for *arr PUTs**: encode full model with `JSONEncoder`, convert to `[String: Any]` via `JSONSerialization.jsonObject`, override specific keys, re-encode and PUT — required because *arr APIs expect the full object back but Swift model structs have no memberwise init
- **`ReleaseModels`** (`Models/ReleaseModels.swift`) — shared `Decodable` structs for Radarr/Sonarr/Lidarr release responses

## API Endpoints Used

| Service | Base path | Auth |
| ------- | --------- | ---- |
| Radarr | `/api/v3/movie`, `/api/v3/movie/lookup`, `/api/v3/command`, `/api/v3/rootfolder`, `/api/v3/qualityprofile`, `/api/v3/tag`, `/api/v3/release`, `/api/v3/queue`, `/api/v3/queue/{id}`, `/api/v3/queue/grab` | `X-Api-Key` header |
| Sonarr | `/api/v3/series`, `/api/v3/series/lookup`, `/api/v3/episode`, `/api/v3/episodefile`, `/api/v3/episodefile/bulk`, `/api/v3/tag`, `/api/v3/release`, `/api/v3/queue`, `/api/v3/queue/{id}`, `/api/v3/queue/grab` | `X-Api-Key` header |
| Lidarr | `/api/v1/artist`, `/api/v1/artist/lookup`, `/api/v1/album`, `/api/v1/album/{id}`, `/api/v1/track`, `/api/v1/trackfile`, `/api/v1/tag`, `/api/v1/release`, `/api/v1/queue`, `/api/v1/queue/{id}`, `/api/v1/queue/grab` | `X-Api-Key` header |
| Transmission | `/transmission/rpc` | Basic auth + session ID |
| api.country.is | `/{ip}` | None (rate-limited to 10 req/s in batches) |

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

## Swift code conventions

- Use 2-space indentation
- Prefer SwiftUI over UIKit unless explicitly targeting UIKit
- Target iOS 26 and Swift 6.2
- Use async/await over completion handlers
- Prefer structured concurrency over unstructured tasks

## Testing

- Write tests for all new logic using Swift Testing
- Prefer testing behavior over implementation details
