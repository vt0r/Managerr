# [Managerr](https://managerr.app)

A native iOS/macOS app that brings Radarr, Sonarr, Lidarr, and Transmission together in one clean dashboard.

<!-- markdownlint-disable MD033 -->
[<img src=".resources/Download_on_the_App_Store_Badge_US-UK_RGB_blk_092917.svg" alt="Download Managerr on the App Store">](https://apps.apple.com/app/id6759478095)
<!-- markdownlint-enable MD033 -->

## Features

- **Movies** - Browse your Radarr library, toggle monitoring, trigger auto or manual searches, add new movies, edit quality profile / availability / tags, access the Radarr activity queue, and view missing or cutoff-unmet movies in the Wanted list
- **TV Shows** - View your Sonarr series, drill into seasons and episodes, toggle monitoring per season or episode, trigger searches, edit series settings (quality, type, tags, season folders), access the Sonarr activity queue, and view missing or cutoff-unmet episodes in the Wanted list
- **Music** - Explore artists and albums via Lidarr, monitor releases, search for missing albums, edit artist and album settings (quality, metadata profile, tags, release selection), access the Lidarr activity queue, and view missing or cutoff-unmet albums in the Wanted list
- **Downloads** - Monitor active Transmission torrents with live-updating per-torrent details, peers (with optional country flags), trackers, and file lists; set bandwidth priority per torrent or per individual file; toggle whether individual files are downloaded; add, edit (URL and tier), and remove trackers
- **Settings** - Configure each service independently with built-in connection testing
- **Open in Browser** - Each service tab has an option to open the service's web UI in your default browser - if you find yourself using this often, please [create an issue](https://github.com/vt0r/Managerr/issues/new/choose) to let us know which feature(s) is (are) missing!

## Development and Contributing

If you'd like to contribute to this project, or if you just want to build and run it locally, please review the following information. Please do not forget to read the [Accessibility](#accessibility) section below also! Thank you in advance for any help you're able to provide with this project, be it creating PRs to add functionality, creating issues to report problems or to make feature requests, or just simply providing feedback. It is much appreciated in any (polite and courteous) form, and we love to hear from you.

### Requirements

- iOS 18+ or macOS 14+ (runs like an iPad app on macOS)
- Xcode 15+
- One or more self-hosted services:
  - [Radarr](https://radarr.video)
  - [Sonarr](https://sonarr.tv)
  - [Lidarr](https://lidarr.audio)
  - [Transmission](https://transmissionbt.com)

You can use the app with any combination of the above services - just enable the ones you have.

### Getting Started

1. Clone the repo and open `Managerr.xcodeproj` in Xcode
2. Select your target device or simulator and run
3. Open the **Settings** tab in the app
4. Tap a service, enter its URL and credentials, then tap **Test Connection** to verify
5. Tap **Save** - the service is now live

#### Service URLs

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

#### Credentials

| Service | Credential |
| ------- | ---------- |
| Radarr | API Key (found in `Settings → General`) |
| Sonarr | API Key (found in `Settings → General`) |
| Lidarr | API Key (found in `Settings → General`) |
| Transmission | `username:password` (leave blank if RPC auth is disabled) |

### Project Structure

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

No external dependencies - pure Swift, SwiftUI, and Foundation.

### Accessibility

Accessibility is a core value of this project, not an afterthought. Managerr aims for full support of every iOS accessibility feature - VoiceOver, Switch Control, Voice Control, Dynamic Type, Reduce Motion, and more - and we actively work to close any gaps we find. Users who depend on these features deserve the same full experience as anyone else.

We warmly welcome contributions from everyone, including those who are still learning the accessibility APIs. If your PR misses something, we will fix it up - please don't let unfamiliarity with the topic stop you from contributing. The [AGENTS.md](AGENTS.md) file has the full technical spec if you want to go deep.

#### Guidelines

**Label every interactive element that lacks visible text.**
Buttons, toggles, and tappable cards that use only an icon need `.accessibilityLabel("…")`. Concise noun/verb phrases work best ("Add tracker", "Toggle monitoring").

**Hide decorative images.**
Poster thumbnails, fanart backgrounds, and gradient overlays are pure decoration - apply `.accessibilityHidden(true)` to their outermost container so VoiceOver skips them entirely.

**Collapse compound rows into a single VoiceOver element.**
List rows and cards that contain multiple sub-views (icon + title + status) should present as one element: `.accessibilityElement(children: .ignore)` + `.accessibilityLabel(…)` + `.accessibilityAddTraits(.isButton)`. This gives VoiceOver a single, coherent description instead of a stream of fragments.

**Convey state in text, not colour alone.**
Red/green dots, filled/unfilled icons, and tinted text are invisible to VoiceOver. Include the state in `.accessibilityLabel` or `.accessibilityValue` (e.g. `monitored ? "Monitored" : "Not monitored"`).

**Label or hide every ProgressView.**
A bare spinner announces nothing useful. Either label it (`.accessibilityLabel("Loading albums")`) or hide it (`.accessibilityHidden(true)`) when the progress percentage is conveyed elsewhere in the same row.

**Use semantic font styles for Dynamic Type.**
Prefer `.caption`, `.subheadline`, `.headline`, etc. over hard-coded point sizes. If a fixed size is unavoidable, add `.minimumScaleFactor(0.7)` so text scales down instead of clipping.

**Hints are a bonus.**
`.accessibilityHint("…")` can clarify a non-obvious action. Keep them short and in the third person ("Toggles whether this file is downloaded").
