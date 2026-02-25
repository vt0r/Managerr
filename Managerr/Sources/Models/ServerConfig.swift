import Foundation

nonisolated enum TabSelection: String, CaseIterable, Sendable {
    case movies
    case tvShows
    case music
    case downloads
    case search
    case settings
}

nonisolated struct ServerConfig: Codable, Identifiable, Sendable {
    var id: String { serviceType.rawValue }
    var url: String
    var apiKey: String
    var isEnabled: Bool
    var serviceType: ServiceType

    nonisolated enum ServiceType: String, Codable, CaseIterable, Sendable {
        case radarr
        case sonarr
        case lidarr
        case transmission

        var displayName: String {
            switch self {
            case .radarr: "Radarr"
            case .sonarr: "Sonarr"
            case .lidarr: "Lidarr"
            case .transmission: "Transmission"
            }
        }

        var defaultPort: Int {
            switch self {
            case .radarr: 7878
            case .sonarr: 8989
            case .lidarr: 8686
            case .transmission: 9091
            }
        }

        var credType: String {
            switch self {
            case .radarr: "API Key"
            case .sonarr: "API Key"
            case .lidarr: "API Key"
            case .transmission: "Credentials (user:pass)"
            }
        }

        var credSummary: AttributedString {
            switch self {
            case .radarr: try! AttributedString(
                markdown: "The API key used to authenticate to \(displayName). This can typically be found in **Settings --> General**.")
            case .sonarr: try! AttributedString(
                markdown: "The API key used to authenticate to \(displayName). This can typically be found in **Settings --> General**.")
            case .lidarr: try! AttributedString(
                markdown: "The API key used to authenticate to \(displayName). This can typically be found in **Settings --> General**.")
            case .transmission: try! AttributedString(
                markdown: "The RPC credentials used to authenticate to \(displayName) (leave blank for none).")
            }
        }

        var icon: String {
            switch self {
            case .radarr: "film"
            case .sonarr: "tv"
            case .lidarr: "music.note"
            case .transmission: "arrow.down.circle"
            }
        }
    }

    var baseURL: URL? {
        URL(string: url)
    }

    static func defaultConfig(for type: ServiceType) -> ServerConfig {
        let defaultURL: String
        switch type {
        case .radarr: defaultURL = "http://localhost:7878"
        case .sonarr: defaultURL = "http://localhost:8989"
        case .lidarr: defaultURL = "http://localhost:8686"
        case .transmission: defaultURL = "http://localhost:9091"
        }
        return ServerConfig(url: defaultURL, apiKey: "", isEnabled: false, serviceType: type)
    }
}
