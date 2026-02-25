import Foundation

nonisolated struct RadarrMovie: Codable, Identifiable, Sendable, Hashable {
    let id: Int
    let title: String
    let sortTitle: String?
    let year: Int?
    let overview: String?
    let monitored: Bool
    let hasFile: Bool
    let status: String?
    let runtime: Int?
    let tmdbId: Int?
    let imdbId: String?
    let genres: [String]?
    let ratings: RadarrRatings?
    let images: [MediaImage]?
    let sizeOnDisk: Int64?
    let added: String?
    let movieFile: RadarrMovieFile?
    let qualityProfileId: Int?
    let path: String?
    let rootFolderPath: String?
    let minimumAvailability: String?
    let inCinemas: String?
    let digitalRelease: String?
    let physicalRelease: String?
    let certification: String?

    enum CodingKeys: String, CodingKey {
        case id, title, sortTitle, year, overview, monitored, hasFile, status, runtime
        case tmdbId, imdbId, genres, ratings, images, sizeOnDisk, added, movieFile
        case qualityProfileId, path, rootFolderPath, minimumAvailability
        case inCinemas, digitalRelease, physicalRelease, certification
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "Unknown"
        monitored = try c.decodeIfPresent(Bool.self, forKey: .monitored) ?? false
        hasFile = try c.decodeIfPresent(Bool.self, forKey: .hasFile) ?? false
        sortTitle = try c.decodeIfPresent(String.self, forKey: .sortTitle)
        year = try c.decodeIfPresent(Int.self, forKey: .year)
        overview = try c.decodeIfPresent(String.self, forKey: .overview)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        runtime = try c.decodeIfPresent(Int.self, forKey: .runtime)
        tmdbId = try c.decodeIfPresent(Int.self, forKey: .tmdbId)
        imdbId = try c.decodeIfPresent(String.self, forKey: .imdbId)
        genres = try c.decodeIfPresent([String].self, forKey: .genres)
        ratings = try c.decodeIfPresent(RadarrRatings.self, forKey: .ratings)
        images = try c.decodeIfPresent([MediaImage].self, forKey: .images)
        sizeOnDisk = try c.decodeIfPresent(Int64.self, forKey: .sizeOnDisk)
        added = try c.decodeIfPresent(String.self, forKey: .added)
        movieFile = try c.decodeIfPresent(RadarrMovieFile.self, forKey: .movieFile)
        qualityProfileId = try c.decodeIfPresent(Int.self, forKey: .qualityProfileId)
        path = try c.decodeIfPresent(String.self, forKey: .path)
        rootFolderPath = try c.decodeIfPresent(String.self, forKey: .rootFolderPath)
        minimumAvailability = try c.decodeIfPresent(String.self, forKey: .minimumAvailability)
        inCinemas = try c.decodeIfPresent(String.self, forKey: .inCinemas)
        digitalRelease = try c.decodeIfPresent(String.self, forKey: .digitalRelease)
        physicalRelease = try c.decodeIfPresent(String.self, forKey: .physicalRelease)
        certification = try c.decodeIfPresent(String.self, forKey: .certification)
    }

    var gridBadge: String? {
        guard !hasFile else { return nil }
        switch status {
        case "released": return "MISSING"
        case "inCinemas": return "IN CINEMAS"
        case "announced": return "ANNOUNCED"
        case "tba": return "TBA"
        default: return nil
        }
    }

    var posterImagePath: String? {
        let img = images?.first(where: { $0.coverType == "poster" })
        return img?.remoteUrl ?? img?.url
    }

    var fanartImagePath: String? {
        let img = images?.first(where: { $0.coverType == "fanart" })
        return img?.remoteUrl ?? img?.url
    }

    func posterURL(baseURL: URL?) -> URL? {
        ImageURLResolver.resolve(posterImagePath, baseURL: baseURL)
    }

    func fanartURL(baseURL: URL?) -> URL? {
        ImageURLResolver.resolve(fanartImagePath, baseURL: baseURL)
    }

    static func == (lhs: RadarrMovie, rhs: RadarrMovie) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

nonisolated struct RadarrRatings: Codable, Sendable {
    let imdb: RatingValue?
    let tmdb: RatingValue?
    let rottenTomatoes: RatingValue?

    nonisolated struct RatingValue: Codable, Sendable {
        let votes: Int?
        let value: Double?
        let type: String?
    }
}

nonisolated struct RadarrMovieFile: Codable, Sendable {
    let id: Int?
    let relativePath: String?
    let size: Int64?
    let quality: RadarrQualityWrapper?
}

nonisolated struct RadarrQualityWrapper: Codable, Sendable {
    let quality: RadarrQuality?
}

nonisolated struct RadarrQuality: Codable, Sendable {
    let id: Int?
    let name: String?
    let resolution: Int?
}

nonisolated struct MediaImage: Codable, Sendable {
    let coverType: String?
    let url: String?
    let remoteUrl: String?
}

nonisolated struct RadarrCommand: Codable, Sendable {
    let name: String
    let movieIds: [Int]?
}

nonisolated struct RadarrRootFolder: Codable, Identifiable, Sendable {
    let id: Int
    let path: String
    let freeSpace: Int64?
}

nonisolated struct RadarrQualityProfile: Codable, Identifiable, Sendable {
    let id: Int
    let name: String
}
