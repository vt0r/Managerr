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
- **`TransmissionService`** — JSON-RPC 2.0 client; manages `X-Transmission-Session-Id` (auto-retries on 409); supports Basic auth; RPC methods include `torrent-get`, `torrent-set` (priority, tracker list, file wanted), `torrent-start/stop/remove/verify/reannounce`, `torrent-add`, `session-get/set`; `setTrackerList` sends a newline-separated `trackerList` string (blank lines separate tiers, requires Transmission 4+ / RPC v17); `removeTracker` uses `trackerRemove` array
- **`SettingsStore`** — `@Observable`; persists `ServerConfig` per service to `UserDefaults` as JSON
- **`ImageLoader`** (`Services/ImageCache.swift`) — `actor`; 3-tier image cache: memory (LRU, 400-image cap) → disk (`Caches/ManagerrImages/`, SHA256-keyed filenames, indefinite retention) → network. Uses `byPreparingForDisplay()` for background decoding so the main thread never decodes a JPEG/PNG. Retries up to 3×; 404 is treated as final (no retry). Max 10 concurrent prefetch ops to prevent OOM on large libraries. `prefetch(urls:)` is called from Radarr/Sonarr/LidarrViewModels after data loads. The SwiftUI wrapper is `CachedAsyncImage` (`Views/CachedAsyncImage.swift`), which fades in loaded images.

## Key Models

- **`ServerConfig`** (`Models/ServerConfig.swift`) — unified config struct with `ServiceType` enum (radarr, sonarr, lidarr, transmission); also defines `TabSelection` enum
- **`TransmissionTorrent`** (`Models/TransmissionModels.swift`) — status is an `Int` (0=Stopped, 4=Downloading, 6=Seeding); `bandwidthPriority: Int?` maps to `TorrentPriority` enum (low=−1, normal=0, high=1); `AnyCodable` handles flexible JSON
- **`TorrentPriority`** (`Models/TransmissionModels.swift`) — `enum` with raw value `Int`; cases `low`, `normal`, `high`; exposes `label`, `icon` (SF Symbol name), and `color`; used for both torrent-level bandwidth priority and per-file priority
- **`WantedItem`** (`Models/WantedModels.swift`) — unified wanted-media wrapper; `WantedContent` enum with associated values `movie(RadarrMovie)`, `episode(SonarrEpisode)`, `album(LidarrAlbum)`; `WantedItem` (nonisolated struct) wraps content + service and exposes `primaryTitle`, `secondaryTitle`, `detailText`, `monitored`, `isAvailable` (date-based derivation: movie `status == "released"`, episode `airDate <= today`, album `releaseDate.prefix(10) <= today`), and `qualityLabel` (Radarr only: `movieFile?.quality?.quality?.name`; nil for Sonarr/Lidarr) computed properties for uniform display. `WantedFilter` enum (missing / cutoffUnmet) has a `nonisolated` `endpoint` property returning the URL path segment; `nonisolated` prevents `@MainActor` inference when the enum is stored on a `@MainActor @Observable` class. `WantedPageResponse<T>` is the generic paginated response wrapper. Note: `fetchSonarrWanted` includes `includeSeries=true` so that `episode.series` is populated; without it `primaryTitle` falls back to "Unknown Series".
- **`ArrQueueRecord`** (`Models/QueueModels.swift`) — unified queue item for all three *arrs; `protocol` is decoded via `CodingKeys` to `downloadProtocol`; embeds optional `ArrQueueMovie/Series/Episode/Artist/Album` for display title construction; all structs are `nonisolated` to satisfy `Sendable` constraints
- **`ArrTag`** (`Models/RadarrModels.swift`) — shared `nonisolated struct` (`id: Int`, `label: String`) used by all three *arrs for tag management in edit sheets
- **`LidarrAlbumRelease`** (`Models/LidarrModels.swift`) — release record embedded in `LidarrAlbum`; fields: `id`, `title`, `mediumCount`, `trackCount`, `releaseDate`, `status`, `monitored`
- Radarr/Sonarr/Lidarr models are straightforward `Decodable` structs mirroring their v3/v1 API responses; `RadarrMovie`, `SonarrSeries`, and `LidarrArtist` include `tags: [Int]?`; `SonarrSeries` adds `monitorNewItems: String?` and `seasonFolder: Bool?`; `LidarrArtist` adds `monitorNewItems: String?`; `LidarrAlbum` adds `anyReleaseOk: Bool?` and `releases: [LidarrAlbumRelease]?`

## ViewModels

All use `@Observable` (not `ObservableObject`). Key patterns:

- `filteredMovies`/`filteredSeries`/etc. are computed properties applying search + sort
- Sort orders are nested enums on each ViewModel
- `LidarrViewModel` has a `viewMode` (Artists vs Albums) and fetches both concurrently with `async let`
- `TransmissionViewModel` tracks `filterStatus` (All/Downloading/Seeding/Stopped), `sortOption` (Name/DateAdded/Size/Progress/Ratio/Speed), and `sortAscending`. Exposes aggregate `totalDownloadSpeed`/`totalUploadSpeed`. `peerCountries: [String: String]` caches IP → country code lookups (batched at 10/s via `api.country.is`). `detailedTorrent` is populated by `fetchTorrentDetail` which is called once on sheet open then polled every 5 seconds. Priority methods: `setTorrentPriority` (sends `bandwidthPriority` via `torrent-set`), `setFilePriority` (sends `priority-high/normal/low`), `setFilesWanted` (sends `files-wanted/files-unwanted`). Tracker methods: `addTracker` and `replaceTracker` rebuild the full tracker list string (newline-separated URLs, blank lines between tiers) and send it via `setTrackerList`; `removeTracker` uses `trackerRemove` directly. Private helpers `buildTrackerList(from:adding:tier:)`, `buildTrackerList(from:replacing:with:tier:)`, and `trackerListString(from:)` encapsulate the list reconstruction.
- `QueueViewModel` is always scoped to a single service via a required `service: ServiceType` property (non-optional; `QueueView` is only ever launched from within a specific *arr tab). Fetches the queue for that service, exposes `filteredItems` (computed, driven by `statusFilter: QueueStatusFilter`), and auto-polls every 30 seconds via a `while !Task.isCancelled` loop in `.task`. `QueueStatusFilter` is an enum: All / Active / Warning / Error. `isFiltered` is simply `statusFilter != .all`.
- `WantedViewModel` is always scoped to a single service via a required `service: ServiceType` property (non-optional; mirrors `QueueViewModel`'s pattern). `fetch` performs a single-service fetch for the current `filter` (.missing / .cutoffUnmet), replaces `items` atomically, and stores any error in `errorMessages`. `autoSearch` sends a `MoviesSearch`/`EpisodeSearch`/`AlbumSearch` command to the service. `unmonitor` PUTs the full object back with `monitored: false` then removes the item from the list.

## Views

- **`PosterGridView`** — shared reusable card (poster image, title, subtitle, badge); used by all media service grids
- Detail views are presented as sheets (`.sheet`), not pushed navigation
- Grids use `LazyVGrid` with adaptive columns (`minimum: 110`)
- Settings are in `SettingsView` + `ServiceConfigSheet`; connection testing is done inline
- **`ManualSearchView`** — generic sheet for browsing and grabbing indexer releases; used by movie, season, episode, and album detail sheets
- **`SeasonDetailSheet`** — episode list for a single season; supports per-episode and per-season monitored toggling, file deletion, and manual/auto search
- **`QueueView`** — service-scoped activity-queue sheet; always launched with a required service argument `QueueView(service: .radarr/.sonarr/.lidarr)` from each *arr view's `•••` menu (labelled "Activity" to match the *arr web UI); card layout (`ScrollView + LazyVStack`, `secondarySystemBackground` rounded rect per item) consistent with the Downloads view; each row shows a status icon left of the title (matching the Downloads view pattern): `arrow.down.circle.fill` downloading, `clock` queued, `pause.circle.fill` paused, `checkmark.circle.fill` completed, `tray.and.arrow.down.fill` importing/import-pending, `xmark.circle.fill` failed, `exclamationmark.clock` delayed, `arrow.down.circle.badge.xmark` no client; filter menu (status only: All/Active/Warning/Error); tap opens `QueueDetailSheet`; long-press context menu provides Force Grab (delayed items only) and Remove shortcuts
- **`WantedView`** — service-scoped wanted-media sheet; always launched with a required service argument `WantedView(service: .radarr/.sonarr/.lidarr)` from each *arr view's `•••` menu below "Activity"; card layout matching QueueView; each row shows a filter-aware indicator flush-right: for Missing — `exclamationmark.triangle.fill` (orange) when content is released/aired, `calendar.badge.clock` (secondary) when not yet available; for Cutoff Unmet — quality text capsule when available from the model (Radarr only), `arrow.up.circle` icon otherwise; filter menu (`line.3.horizontal.decrease.circle`, fills for Cutoff Unmet) switches between Missing and Cutoff Unmet; ellipsis menu contains Refresh; tap opens `WantedDetailSheet`; long-press context menu provides Auto Search, Manual Search (opens `WantedDetailSheet`), and Unmonitor shortcuts
- **`QueueDetailSheet`** — flat header (content-type label left, status pill right using status color, title below); progress section with size breakdown, percentage, ETA, and estimated completion as a relative `Text(date, style: .relative)`; download details section (protocol, client, indexer, full selectable release name); status messages panel shown only when warnings/errors are present; Force Grab and Remove actions at the bottom
- **`WantedDetailSheet`** — flat header matching `QueueDetailSheet` style (content-type label left, filter pill right — orange for Missing, yellow for Cutoff Unmet, title below, secondary title if present); per-content details section (movie: runtime/status/genres/overview; episode: S##E## code/air date/overview; album: type/release date/overview); action buttons: Auto Search (`.borderedProminent`), Manual Search (opens `ManualSearchView`), Unmonitor (`.destructive`)
- **`TorrentDetailSheet`** — detail sheet for a single Transmission torrent; polled every 5 seconds via `.task`; includes a bandwidth-priority section (segmented `Picker` backed by `TorrentPriority`, sends `torrent-set bandwidthPriority`); file list shows a wanted toggle (checkmark/circle, sends `files-wanted/files-unwanted`) and a priority `Menu` (Low/Normal/High, sends `priority-high/normal/low`) per file; also shows progress header, transfer stats, peers, trackers link, and action buttons (Start/Stop, Verify, Remove)
- **`TrackerListView`** — tracker management for a torrent; grouped by tier; `+` toolbar button opens `TrackerEditSheet` to add a tracker; swipe-leading opens edit sheet pre-filled with current URL and tier; swipe-trailing (full-swipe) deletes via `trackerRemove`; long-press context menu mirrors swipe actions; `TrackerEditSheet` (private) is a `NavigationStack`-wrapped form with a URL text field (keyboard type `.URL`) and a `Stepper` for tier (0 to `maxTier + 1`, where `maxTier + 1` creates a new tier); tier changes are applied by rebuilding the full `trackerList` string and sending it via `torrent-set`
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
| Radarr | `/api/v3/movie`, `/api/v3/movie/lookup`, `/api/v3/command`, `/api/v3/rootfolder`, `/api/v3/qualityprofile`, `/api/v3/tag`, `/api/v3/release`, `/api/v3/queue`, `/api/v3/queue/{id}`, `/api/v3/queue/grab`, `/api/v3/wanted/missing`, `/api/v3/wanted/cutoff` | `X-Api-Key` header |
| Sonarr | `/api/v3/series`, `/api/v3/series/lookup`, `/api/v3/episode`, `/api/v3/episodefile`, `/api/v3/episodefile/bulk`, `/api/v3/tag`, `/api/v3/release`, `/api/v3/queue`, `/api/v3/queue/{id}`, `/api/v3/queue/grab`, `/api/v3/wanted/missing`, `/api/v3/wanted/cutoff` | `X-Api-Key` header |
| Lidarr | `/api/v1/artist`, `/api/v1/artist/lookup`, `/api/v1/album`, `/api/v1/album/{id}`, `/api/v1/track`, `/api/v1/trackfile`, `/api/v1/tag`, `/api/v1/release`, `/api/v1/queue`, `/api/v1/queue/{id}`, `/api/v1/queue/grab`, `/api/v1/wanted/missing`, `/api/v1/wanted/cutoff` | `X-Api-Key` header |
| Transmission | `/transmission/rpc` | Basic auth + session ID |
| api.country.is | `/{ip}` | None (rate-limited to 10 req/s in batches) |

## Accessibility Standards

**For automated contributions, accessibility is not optional and is not best-effort. It is a hard requirement, on par with compilation.** Any PR or commit from an agent that adds or modifies a SwiftUI view must include correct, complete accessibility coverage for every new or changed element. A missing `.accessibilityLabel` on a button, a missing `.accessibilityHidden(true)` on a decorative image, or a ProgressView without a label is a defect that must be fixed in the same commit — not deferred, not left as a TODO. If you are unsure whether a particular element needs accessibility treatment, apply it. The cost of a false positive is zero; the cost of a missed label is a broken experience for users who depend on VoiceOver, Switch Control, or Voice Control.

Human contributors: we warmly welcome your contributions and understand that accessibility is a wide and complex topic. Please do your best with the guidelines below, and if you miss something we will fix it up — this strict framing is aimed at automated tooling, not at you.

### Rules

Every rule applies to any new element you add or existing element you significantly modify.

---

**Every interactive element must be labelled.**
Any button, toggle, or tappable area that uses only an icon (SF Symbol or image) with no adjacent visible text requires `.accessibilityLabel("…")`. Prefer concise noun/verb phrases. Examples:

```swift
Button { … } label: { Image(systemName: "plus") }
    .accessibilityLabel("Add Tracker")

Menu { … } label: { Image(systemName: "ellipsis.circle") }
    .accessibilityLabel("More options")
```

Icon-only buttons inside toolbars and cells are the most common miss — check every `Image(systemName:)` that lives inside a tappable container.

---

**Every decorative image must be hidden.**
Poster thumbnails, fanart backgrounds, cover art, placeholder images, and gradient overlays are pure decoration. Apply `.accessibilityHidden(true)` to the outermost container, not just the inner `Image` or `CachedAsyncImage`. This includes:

- `CachedAsyncImage` in list/grid cells and header overlays
- `Color(…).overlay { CachedAsyncImage(…) }` thumbnail containers
- `LinearGradient` overlays used for visual fade-out effects
- `Image(systemName:)` used as a visual-only placeholder (e.g. `"photo"`, `"film"`, `"music.mic"`)

`CachedAsyncImage` is always used decoratively in this codebase. Its component-level `.accessibilityHidden(true)` is already set, but the wrapping container (a `Color` or `Group`) must also be hidden whenever it is used as a thumbnail.

---

**ProgressView must be labelled or hidden.**
A bare `ProgressView()` or `ProgressView(value:)` announces nothing useful to VoiceOver. Choose one:

- If it conveys state already communicated by nearby text or by the parent element's label/value, hide it: `.accessibilityHidden(true)`
- If it is the only indicator of loading activity (e.g. a standalone spinner while content loads), label it: `.accessibilityLabel("Loading…")`

In-row progress bars (torrent progress, queue progress, season completion) always use `.accessibilityHidden(true)` because the percentage is available as text elsewhere in the same row.

---

**Compound cards collapse into a single element.**
List rows and grid cards that consist of multiple sub-views (icon + title + status + value) must present as one VoiceOver element, not a sequence of individually-navigable fragments. Use `.accessibilityElement(children: .ignore)` (not `.combine`) plus a hand-crafted label and value that encode all meaningful state:

```swift
Button { … } label: { CardView(item: item) }
    .accessibilityElement(children: .ignore)   // suppress child traversal
    .accessibilityLabel(item.primaryTitle)
    .accessibilityValue("\(item.status), \(item.isMonitored ? "monitored" : "not monitored")")
    .accessibilityAddTraits(.isButton)
```

Avoid `.accessibilityElement(children: .combine)` for cards — it concatenates child text in unpredictable order and often includes visual-only fragments. Prefer `.ignore` with an explicit string.

Calendar row views (`RadarrCalendarRow`, `SonarrCalendarRow`, `LidarrCalendarRow`) use this pattern; their labels encode title, episode/type info, and download/monitored status.

---

**State must be expressed via label or value, not colour alone.**
Any element whose meaning changes based on state must communicate that state accessibly. Red/green dots, filled/unfilled icons, tinted text — none of these alone are sufficient. Include the state in:

- `.accessibilityLabel(…)` — when the state defines what the element *is* (e.g. `"Monitored"` / `"Not monitored"` for a toggle button)
- `.accessibilityValue(…)` — when the state is a property of a fixed-label element (e.g. a service row whose label is always the service name but whose value is `"Enabled"` / `"Not configured"`)
- `.accessibilityAddTraits(.isSelected)` — for multi-select list items that toggle a selected/deselected state

Status dots (the small green/grey circle in `SettingsView`) are decorative; hide them with `.accessibilityHidden(true)` and put the state in the parent button's `.accessibilityValue`.

---

**Selection state must be conveyed.**
In multi-select list views, selected items must carry `.accessibilityAddTraits(.isSelected)`. The accessibility value should also include "selected" to support screen readers that may not announce the selected trait automatically.

---

**Dynamic Type must not break layouts.**
Never hard-code font sizes with `.font(.system(size: N))` — use semantic styles (`.caption`, `.headline`, etc.). If a fixed size is truly unavoidable, pair it with `.minimumScaleFactor(0.7)` and a `lineLimit` that permits wrapping.

---

**Hints are optional but welcome.**
`.accessibilityHint("…")` can clarify what a non-obvious action does. Keep hints short and in the third person ("Toggles whether this file is downloaded"). Do not duplicate information already in the label or value.

---

### Common Mistakes in This Codebase

These are the categories of issues most commonly missed. Review each when writing or reviewing view code:

| Category | What to check |
|---|---|
| Icon-only toolbar buttons | Every `Image(systemName:)` inside a `ToolbarItem` button or `Menu` label |
| Inline icon buttons inside rows | Search/magnify icons, priority menus, close/remove buttons on chips |
| ProgressView in rows and headers | Must be `.accessibilityHidden(true)` unless it is the *only* loading indicator |
| Poster/fanart/thumbnail containers | The outer `Color` or `Group` wrapper, not just the inner `CachedAsyncImage` |
| Gradient overlays | `LinearGradient` used purely for visual fade — always hidden |
| Queue/Wanted row buttons | Must use `.accessibilityElement(children: .ignore)` + label + value; never rely on `.combine` |
| Calendar rows | Must use `.ignore` + explicit label; never `.combine` |
| Status colour indicators | Small dots and filled/unfilled icons — the parent must carry the state as text |
| ProgressView spinners | Loading spinners in section headers (albums, episodes, tracks) need a label |

### Agent Pre-Submit Checklist

Before finalising any commit that touches a SwiftUI view, verify each of the following. Submitting without checking these is the same as skipping compilation.

- [ ] Every new button/toggle/tappable card has `.accessibilityLabel` if it has no visible text label
- [ ] Every new `ProgressView` is either labelled or hidden
- [ ] Every decorative image container has `.accessibilityHidden(true)` on its outermost modifier
- [ ] Every new compound list/grid row uses `.accessibilityElement(children: .ignore)` with a hand-crafted label
- [ ] No element communicates state via colour or icon shape alone without a textual equivalent
- [ ] Run Xcode's Accessibility Inspector (`Xcode → Open Developer Tool → Accessibility Inspector`) against the simulator and resolve all warnings before submitting

## Swift code conventions

- Use 2-space indentation
- Prefer SwiftUI over UIKit unless explicitly targeting UIKit
- Target iOS 26 and Swift 6.2
- Use async/await over completion handlers
- Prefer structured concurrency over unstructured tasks

## Testing

- Write tests for all new logic using Swift Testing
- Prefer testing behavior over implementation details
