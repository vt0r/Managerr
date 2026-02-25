import Foundation

nonisolated struct SonarrSeries: Codable, Identifiable, Sendable, Hashable {
    let id: Int
    let title: String
    let sortTitle: String?
    let year: Int?
    let overview: String?
    let monitored: Bool
    let status: String?
    let network: String?
    let runtime: Int?
    let tvdbId: Int?
    let imdbId: String?
    let genres: [String]?
    let ratings: SonarrRatings?
    let images: [MediaImage]?
    let seasons: [SonarrSeason]?
    let statistics: SonarrStatistics?
    let added: String?
    let path: String?
    let rootFolderPath: String?
    let qualityProfileId: Int?
    let seriesType: String?

    enum CodingKeys: String, CodingKey {
        case id, title, sortTitle, year, overview, monitored, status, network, runtime
        case tvdbId, imdbId, genres, ratings, images, seasons, statistics, added
        case path, rootFolderPath, qualityProfileId, seriesType
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "Unknown"
        monitored = try c.decodeIfPresent(Bool.self, forKey: .monitored) ?? false
        sortTitle = try c.decodeIfPresent(String.self, forKey: .sortTitle)
        year = try c.decodeIfPresent(Int.self, forKey: .year)
        overview = try c.decodeIfPresent(String.self, forKey: .overview)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        network = try c.decodeIfPresent(String.self, forKey: .network)
        runtime = try c.decodeIfPresent(Int.self, forKey: .runtime)
        tvdbId = try c.decodeIfPresent(Int.self, forKey: .tvdbId)
        imdbId = try c.decodeIfPresent(String.self, forKey: .imdbId)
        genres = try c.decodeIfPresent([String].self, forKey: .genres)
        ratings = try c.decodeIfPresent(SonarrRatings.self, forKey: .ratings)
        images = try c.decodeIfPresent([MediaImage].self, forKey: .images)
        seasons = try c.decodeIfPresent([SonarrSeason].self, forKey: .seasons)
        statistics = try c.decodeIfPresent(SonarrStatistics.self, forKey: .statistics)
        added = try c.decodeIfPresent(String.self, forKey: .added)
        path = try c.decodeIfPresent(String.self, forKey: .path)
        rootFolderPath = try c.decodeIfPresent(String.self, forKey: .rootFolderPath)
        qualityProfileId = try c.decodeIfPresent(Int.self, forKey: .qualityProfileId)
        seriesType = try c.decodeIfPresent(String.self, forKey: .seriesType)
    }

    var posterImagePath: String? {
        let img = images?.first(where: { $0.coverType == "poster" })
        return img?.remoteUrl ?? img?.url
    }

    var fanartImagePath: String? {
        let img = images?.first(where: { $0.coverType == "fanart" })
        return img?.remoteUrl ?? img?.url
    }

    var bannerImagePath: String? {
        let img = images?.first(where: { $0.coverType == "banner" })
        return img?.remoteUrl ?? img?.url
    }

    func posterURL(baseURL: URL?) -> URL? {
        ImageURLResolver.resolve(posterImagePath, baseURL: baseURL)
    }

    func fanartURL(baseURL: URL?) -> URL? {
        ImageURLResolver.resolve(fanartImagePath, baseURL: baseURL)
    }

    static func == (lhs: SonarrSeries, rhs: SonarrSeries) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

nonisolated struct SonarrRatings: Codable, Sendable {
    let votes: Int?
    let value: Double?
}

nonisolated struct SonarrSeason: Codable, Identifiable, Sendable {
    var id: Int { seasonNumber }
    let seasonNumber: Int
    let monitored: Bool
    let statistics: SonarrSeasonStats?
}

nonisolated struct SonarrSeasonStats: Codable, Sendable {
    let episodeFileCount: Int?
    let episodeCount: Int?
    let totalEpisodeCount: Int?
    let sizeOnDisk: Int64?
    let percentOfEpisodes: Double?
}

nonisolated struct SonarrStatistics: Codable, Sendable {
    let seasonCount: Int?
    let episodeFileCount: Int?
    let episodeCount: Int?
    let totalEpisodeCount: Int?
    let sizeOnDisk: Int64?
    let percentOfEpisodes: Double?
}

nonisolated struct SonarrEpisode: Codable, Identifiable, Sendable {
    let id: Int
    let seriesId: Int
    let seasonNumber: Int
    let episodeNumber: Int
    let title: String?
    let overview: String?
    let hasFile: Bool
    let monitored: Bool
    let airDate: String?

    enum CodingKeys: String, CodingKey {
        case id, seriesId, seasonNumber, episodeNumber, title, overview, hasFile, monitored, airDate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decodeIfPresent(Int.self,    forKey: .id)            ?? 0
        seriesId      = try c.decodeIfPresent(Int.self,    forKey: .seriesId)      ?? 0
        seasonNumber  = try c.decodeIfPresent(Int.self,    forKey: .seasonNumber)  ?? 0
        episodeNumber = try c.decodeIfPresent(Int.self,    forKey: .episodeNumber) ?? 0
        title         = try c.decodeIfPresent(String.self, forKey: .title)
        overview      = try c.decodeIfPresent(String.self, forKey: .overview)
        hasFile       = try c.decodeIfPresent(Bool.self,   forKey: .hasFile)       ?? false
        monitored     = try c.decodeIfPresent(Bool.self,   forKey: .monitored)     ?? false
        airDate       = try c.decodeIfPresent(String.self, forKey: .airDate)
    }
}

nonisolated struct SonarrCommand: Codable, Sendable {
    let name: String
    let seriesId: Int?
    let seasonNumber: Int?
    let episodeIds: [Int]?

    init(name: String, seriesId: Int? = nil, seasonNumber: Int? = nil, episodeIds: [Int]? = nil) {
        self.name = name
        self.seriesId = seriesId
        self.seasonNumber = seasonNumber
        self.episodeIds = episodeIds
    }
}

nonisolated struct SonarrRootFolder: Codable, Identifiable, Sendable {
    let id: Int
    let path: String
    let freeSpace: Int64?
}

nonisolated struct SonarrQualityProfile: Codable, Identifiable, Sendable {
    let id: Int
    let name: String
}
