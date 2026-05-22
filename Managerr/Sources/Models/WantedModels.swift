import Foundation

nonisolated struct WantedPageResponse<T: Codable & Sendable>: Codable, Sendable {
    let totalRecords: Int?
    let records: [T]
}

enum WantedFilter: String, CaseIterable, Identifiable, Sendable {
    case missing = "Missing"
    case cutoffUnmet = "Cutoff Unmet"

    var id: String { rawValue }

    nonisolated var endpoint: String {
        switch self {
        case .missing: "missing"
        case .cutoffUnmet: "cutoff"
        }
    }
}

enum WantedContent: Sendable {
    case movie(RadarrMovie)
    case episode(SonarrEpisode)
    case album(LidarrAlbum)
}

nonisolated struct WantedItem: Identifiable, Sendable {
    let service: ServerConfig.ServiceType
    let content: WantedContent

    var id: String {
        switch content {
        case .movie(let m): "radarr-\(m.id)"
        case .episode(let e): "sonarr-\(e.id)"
        case .album(let a): "lidarr-\(a.id)"
        }
    }

    var mediaId: Int {
        switch content {
        case .movie(let m): m.id
        case .episode(let e): e.id
        case .album(let a): a.id
        }
    }

    // Shown large: movie title, series name, or album title
    var primaryTitle: String {
        switch content {
        case .movie(let m):
            if let y = m.year { return "\(m.title) (\(y))" }
            return m.title
        case .episode(let e):
            return e.series?.title ?? "Unknown Series"
        case .album(let a):
            return a.title ?? "Unknown"
        }
    }

    // Shown smaller: episode code/title or artist name
    var secondaryTitle: String? {
        switch content {
        case .movie: return nil
        case .episode(let e):
            let code = String(format: "S%02dE%02d", e.seasonNumber, e.episodeNumber)
            return e.title.map { "\(code) · \($0)" } ?? code
        case .album(let a):
            return a.artist?.artistName
        }
    }

    // Shown smallest: air date or release year
    var detailText: String? {
        switch content {
        case .movie: return nil
        case .episode(let e): return e.airDate
        case .album(let a): return a.releaseDate.map { String($0.prefix(4)) }
        }
    }

    var monitored: Bool {
        switch content {
        case .movie(let m): m.monitored
        case .episode(let e): e.monitored
        case .album(let a): a.monitored
        }
    }

    // Whether the content has been released/aired (used for Missing filter icon)
    var isAvailable: Bool {
        let today = todayString
        switch content {
        case .movie(let m):
            return m.status?.lowercased() == "released"
        case .episode(let e):
            guard let airDate = e.airDate else { return false }
            return airDate <= today
        case .album(let a):
            guard let releaseDate = a.releaseDate else { return false }
            return String(releaseDate.prefix(10)) <= today
        }
    }

    // Current quality label if available from the model (Radarr only; nil otherwise)
    var qualityLabel: String? {
        switch content {
        case .movie(let m): return m.movieFile?.quality?.quality?.name
        case .episode, .album: return nil
        }
    }

    private var todayString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
