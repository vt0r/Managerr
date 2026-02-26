import Foundation

nonisolated struct LidarrArtist: Codable, Identifiable, Sendable, Hashable {
    let id: Int
    let artistName: String?
    let sortName: String?
    let overview: String?
    let monitored: Bool
    let status: String?
    let genres: [String]?
    let images: [MediaImage]?
    let statistics: LidarrArtistStats?
    let added: String?
    let path: String?
    let rootFolderPath: String?
    let qualityProfileId: Int?
    let metadataProfileId: Int?
    let foreignArtistId: String?

    enum CodingKeys: String, CodingKey {
        case id, artistName, sortName, overview, monitored, status, genres, images
        case statistics, added, path, rootFolderPath, qualityProfileId, metadataProfileId, foreignArtistId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        monitored = try c.decodeIfPresent(Bool.self, forKey: .monitored) ?? false
        artistName = try c.decodeIfPresent(String.self, forKey: .artistName)
        sortName = try c.decodeIfPresent(String.self, forKey: .sortName)
        overview = try c.decodeIfPresent(String.self, forKey: .overview)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        genres = try c.decodeIfPresent([String].self, forKey: .genres)
        images = try c.decodeIfPresent([MediaImage].self, forKey: .images)
        statistics = try c.decodeIfPresent(LidarrArtistStats.self, forKey: .statistics)
        added = try c.decodeIfPresent(String.self, forKey: .added)
        path = try c.decodeIfPresent(String.self, forKey: .path)
        rootFolderPath = try c.decodeIfPresent(String.self, forKey: .rootFolderPath)
        qualityProfileId = try c.decodeIfPresent(Int.self, forKey: .qualityProfileId)
        metadataProfileId = try c.decodeIfPresent(Int.self, forKey: .metadataProfileId)
        foreignArtistId = try c.decodeIfPresent(String.self, forKey: .foreignArtistId)
    }

    func posterURL(config: ServerConfig) -> URL? {
        guard let baseURL = config.baseURL else { return nil }
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path = "/api/v1/MediaCover/Artist/\(id)/poster.jpg"
        components?.queryItems = [URLQueryItem(name: "apiKey", value: config.apiKey)]
        return components?.url
    }

    func fanartURL(config: ServerConfig) -> URL? {
        guard let baseURL = config.baseURL else { return nil }
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path = "/api/v1/MediaCover/Artist/\(id)/fanart.jpg"
        components?.queryItems = [URLQueryItem(name: "apiKey", value: config.apiKey)]
        return components?.url
    }

    static func == (lhs: LidarrArtist, rhs: LidarrArtist) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

nonisolated struct LidarrArtistStats: Codable, Sendable {
    let albumCount: Int?
    let trackFileCount: Int?
    let trackCount: Int?
    let totalTrackCount: Int?
    let sizeOnDisk: Int64?
    let percentOfTracks: Double?
}

nonisolated struct LidarrAlbum: Codable, Identifiable, Sendable, Hashable {
    let id: Int
    let title: String?
    let overview: String?
    let artistId: Int?
    let monitored: Bool
    let albumType: String?
    let genres: [String]?
    let images: [MediaImage]?
    let ratings: LidarrRatings?
    let releaseDate: String?
    let duration: Int?
    let artist: LidarrAlbumArtist?
    let statistics: LidarrAlbumStats?

    func coverURL(config: ServerConfig) -> URL? {
        guard let baseURL = config.baseURL else { return nil }
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path = "/api/v1/MediaCover/Album/\(id)/cover.jpg"
        components?.queryItems = [URLQueryItem(name: "apiKey", value: config.apiKey)]
        return components?.url
    }

    static func == (lhs: LidarrAlbum, rhs: LidarrAlbum) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

nonisolated struct LidarrAlbumArtist: Codable, Sendable {
    let id: Int?
    let artistName: String?
}

nonisolated struct LidarrRatings: Codable, Sendable {
    let votes: Int?
    let value: Double?
}

nonisolated struct LidarrAlbumStats: Codable, Sendable {
    let trackFileCount: Int?
    let trackCount: Int?
    let totalTrackCount: Int?
    let sizeOnDisk: Int64?
    let percentOfTracks: Double?
}

nonisolated struct LidarrCommand: Codable, Sendable {
    let name: String
    let artistId: Int?
    let albumIds: [Int]?
}

nonisolated struct LidarrRootFolder: Codable, Identifiable, Sendable {
    let id: Int
    let path: String
    let freeSpace: Int64?
}

nonisolated struct LidarrQualityProfile: Codable, Identifiable, Sendable {
    let id: Int
    let name: String
}

nonisolated struct LidarrMetadataProfile: Codable, Identifiable, Sendable {
    let id: Int
    let name: String
}

nonisolated struct LidarrTrack: Codable, Identifiable, Sendable {
    let id: Int
    let artistId: Int?
    let albumId: Int?
    let trackFileId: Int?
    let title: String?
    let duration: Int?        // milliseconds
    let trackNumber: String?  // Lidarr returns this as a string (e.g. "1", "A1")
    let mediumNumber: Int?    // disc number for multi-disc albums
    let hasFile: Bool

    enum CodingKeys: String, CodingKey {
        case id, artistId, albumId, trackFileId, title, duration
        case trackNumber, mediumNumber, hasFile
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decodeIfPresent(Int.self,    forKey: .id)           ?? 0
        artistId     = try c.decodeIfPresent(Int.self,    forKey: .artistId)
        albumId      = try c.decodeIfPresent(Int.self,    forKey: .albumId)
        trackFileId  = try c.decodeIfPresent(Int.self,    forKey: .trackFileId)
        title        = try c.decodeIfPresent(String.self, forKey: .title)
        duration     = try c.decodeIfPresent(Int.self,    forKey: .duration)
        trackNumber  = try c.decodeIfPresent(String.self, forKey: .trackNumber)
        mediumNumber = try c.decodeIfPresent(Int.self,    forKey: .mediumNumber)
        hasFile      = try c.decodeIfPresent(Bool.self,   forKey: .hasFile)      ?? false
    }
}
