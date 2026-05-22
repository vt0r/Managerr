import Foundation

nonisolated struct ArrQueueResponse: Codable, Sendable {
    let totalRecords: Int?
    let records: [ArrQueueRecord]
}

nonisolated struct ArrQueueRecord: Codable, Identifiable, Sendable {
    let id: Int
    let title: String?
    let status: String?
    let trackedDownloadStatus: String?
    let trackedDownloadState: String?
    let size: Double?
    let sizeleft: Double?
    let timeleft: String?
    let estimatedCompletionTime: String?
    let downloadProtocol: String?
    let downloadClient: String?
    let indexer: String?
    let errorMessage: String?
    let statusMessages: [ArrQueueStatusMessage]?
    let movie: ArrQueueMovie?
    let series: ArrQueueSeries?
    let episode: ArrQueueEpisode?
    let artist: ArrQueueArtist?
    let album: ArrQueueAlbum?

    enum CodingKeys: String, CodingKey {
        case id, title, status, trackedDownloadStatus, trackedDownloadState
        case size, sizeleft, timeleft, estimatedCompletionTime
        case downloadProtocol = "protocol"
        case downloadClient, indexer, errorMessage, statusMessages
        case movie, series, episode, artist, album
    }

    var progressFraction: Double {
        guard let size, let sizeleft, size > 0 else { return 0 }
        return max(0, min(1, (size - sizeleft) / size))
    }

    var displayTitle: String {
        if let movie { return movie.title ?? title ?? "Unknown" }
        if let series {
            if let ep = episode {
                let s = String(format: "%02d", ep.seasonNumber ?? 0)
                let e = String(format: "%02d", ep.episodeNumber ?? 0)
                return "\(series.title ?? "Unknown") S\(s)E\(e)"
            }
            return series.title ?? title ?? "Unknown"
        }
        if let album {
            return "\(artist?.artistName ?? "Unknown") – \(album.title ?? "Unknown")"
        }
        if let artist { return artist.artistName ?? title ?? "Unknown" }
        return title ?? "Unknown"
    }

    var hasWarning: Bool { trackedDownloadStatus?.lowercased() == "warning" }
    var hasError: Bool { trackedDownloadStatus?.lowercased() == "error" }
}

nonisolated struct ArrQueueStatusMessage: Codable, Sendable {
    let title: String?
    let messages: [String]?
}

nonisolated struct ArrQueueMovie: Codable, Sendable {
    let title: String?
    let year: Int?
}

nonisolated struct ArrQueueSeries: Codable, Sendable {
    let title: String?
}

nonisolated struct ArrQueueEpisode: Codable, Sendable {
    let title: String?
    let seasonNumber: Int?
    let episodeNumber: Int?
}

nonisolated struct ArrQueueArtist: Codable, Sendable {
    let artistName: String?
}

nonisolated struct ArrQueueAlbum: Codable, Sendable {
    let title: String?
}
