import Foundation

nonisolated final class ArrService: Sendable {
    static let shared = ArrService()
    private let network = NetworkService.shared

    private init() {}

    private func makeURL(_ config: ServerConfig, path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        guard let baseURL = config.baseURL else { throw NetworkError.invalidURL }
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path = path
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        guard let url = components?.url else { throw NetworkError.invalidURL }
        return url
    }

    private func headers(for config: ServerConfig) -> [String: String] {
        ["X-Api-Key": config.apiKey, "Accept": "application/json"]
    }

    func fetchRadarrMovies(_ config: ServerConfig) async throws -> [RadarrMovie] {
        let url = try makeURL(config, path: "/api/v3/movie")
        return try await network.request(url: url, headers: headers(for: config))
    }

    func lookupRadarrMovie(_ config: ServerConfig, term: String) async throws -> [RadarrMovie] {
        let url = try makeURL(config, path: "/api/v3/movie/lookup", queryItems: [URLQueryItem(name: "term", value: term)])
        return try await network.request(url: url, headers: headers(for: config))
    }

    func deleteRadarrMovie(_ config: ServerConfig, id: Int, deleteFiles: Bool = false) async throws {
        let url = try makeURL(config, path: "/api/v3/movie/\(id)", queryItems: [URLQueryItem(name: "deleteFiles", value: String(deleteFiles))])
        _ = try await network.requestRaw(url: url, method: "DELETE", headers: headers(for: config))
    }

    func commandRadarr(_ config: ServerConfig, command: RadarrCommand) async throws {
        let url = try makeURL(config, path: "/api/v3/command")
        let body = try JSONEncoder().encode(command)
        _ = try await network.requestRaw(url: url, method: "POST", headers: headers(for: config), body: body)
    }

    func fetchRadarrRootFolders(_ config: ServerConfig) async throws -> [RadarrRootFolder] {
        let url = try makeURL(config, path: "/api/v3/rootfolder")
        return try await network.request(url: url, headers: headers(for: config))
    }

    func fetchRadarrQualityProfiles(_ config: ServerConfig) async throws -> [RadarrQualityProfile] {
        let url = try makeURL(config, path: "/api/v3/qualityprofile")
        return try await network.request(url: url, headers: headers(for: config))
    }

    func fetchSonarrSeries(_ config: ServerConfig) async throws -> [SonarrSeries] {
        let url = try makeURL(config, path: "/api/v3/series")
        return try await network.request(url: url, headers: headers(for: config))
    }

    func lookupSonarrSeries(_ config: ServerConfig, term: String) async throws -> [SonarrSeries] {
        let url = try makeURL(config, path: "/api/v3/series/lookup", queryItems: [URLQueryItem(name: "term", value: term)])
        return try await network.request(url: url, headers: headers(for: config))
    }

    func deleteSonarrSeries(_ config: ServerConfig, id: Int, deleteFiles: Bool = false) async throws {
        let url = try makeURL(config, path: "/api/v3/series/\(id)", queryItems: [URLQueryItem(name: "deleteFiles", value: String(deleteFiles))])
        _ = try await network.requestRaw(url: url, method: "DELETE", headers: headers(for: config))
    }

    func commandSonarr(_ config: ServerConfig, command: SonarrCommand) async throws {
        let url = try makeURL(config, path: "/api/v3/command")
        let body = try JSONEncoder().encode(command)
        _ = try await network.requestRaw(url: url, method: "POST", headers: headers(for: config), body: body)
    }

    func fetchSonarrRootFolders(_ config: ServerConfig) async throws -> [SonarrRootFolder] {
        let url = try makeURL(config, path: "/api/v3/rootfolder")
        return try await network.request(url: url, headers: headers(for: config))
    }

    func fetchSonarrQualityProfiles(_ config: ServerConfig) async throws -> [SonarrQualityProfile] {
        let url = try makeURL(config, path: "/api/v3/qualityprofile")
        return try await network.request(url: url, headers: headers(for: config))
    }

    func updateSonarrSeries(_ config: ServerConfig, series: SonarrSeries) async throws {
        let url = try makeURL(config, path: "/api/v3/series/\(series.id)")
        let body = try JSONEncoder().encode(series)
        _ = try await network.requestRaw(url: url, method: "PUT", headers: headers(for: config), body: body)
    }

    func fetchSonarrEpisodes(_ config: ServerConfig, seriesId: Int) async throws -> [SonarrEpisode] {
        let url = try makeURL(config, path: "/api/v3/episode", queryItems: [URLQueryItem(name: "seriesId", value: String(seriesId))])
        return try await network.request(url: url, headers: headers(for: config))
    }

    func fetchLidarrArtists(_ config: ServerConfig) async throws -> [LidarrArtist] {
        let url = try makeURL(config, path: "/api/v1/artist")
        return try await network.request(url: url, headers: headers(for: config))
    }

    func fetchLidarrAlbums(_ config: ServerConfig, artistId: Int? = nil) async throws -> [LidarrAlbum] {
        var queryItems: [URLQueryItem] = []
        if let artistId {
            queryItems.append(URLQueryItem(name: "artistId", value: String(artistId)))
        }
        let url = try makeURL(config, path: "/api/v1/album", queryItems: queryItems)
        return try await network.request(url: url, headers: headers(for: config))
    }

    func fetchLidarrTracks(_ config: ServerConfig, albumId: Int) async throws -> [LidarrTrack] {
        let url = try makeURL(config, path: "/api/v1/track",
                              queryItems: [URLQueryItem(name: "albumId", value: String(albumId))])
        return try await network.request(url: url, headers: headers(for: config))
    }

    func lookupLidarr(_ config: ServerConfig, term: String) async throws -> [LidarrArtist] {
        let url = try makeURL(config, path: "/api/v1/artist/lookup", queryItems: [URLQueryItem(name: "term", value: term)])
        return try await network.request(url: url, headers: headers(for: config))
    }

    func deleteLidarrArtist(_ config: ServerConfig, id: Int) async throws {
        let url = try makeURL(config, path: "/api/v1/artist/\(id)")
        _ = try await network.requestRaw(url: url, method: "DELETE", headers: headers(for: config))
    }

    func commandLidarr(_ config: ServerConfig, command: LidarrCommand) async throws {
        let url = try makeURL(config, path: "/api/v1/command")
        let body = try JSONEncoder().encode(command)
        _ = try await network.requestRaw(url: url, method: "POST", headers: headers(for: config), body: body)
    }

    func fetchLidarrRootFolders(_ config: ServerConfig) async throws -> [LidarrRootFolder] {
        let url = try makeURL(config, path: "/api/v1/rootfolder")
        return try await network.request(url: url, headers: headers(for: config))
    }

    func fetchLidarrQualityProfiles(_ config: ServerConfig) async throws -> [LidarrQualityProfile] {
        let url = try makeURL(config, path: "/api/v1/qualityprofile")
        return try await network.request(url: url, headers: headers(for: config))
    }

    func fetchLidarrMetadataProfiles(_ config: ServerConfig) async throws -> [LidarrMetadataProfile] {
        let url = try makeURL(config, path: "/api/v1/metadataprofile")
        return try await network.request(url: url, headers: headers(for: config))
    }

    func updateLidarrArtist(_ config: ServerConfig, artist: LidarrArtist) async throws {
        let url = try makeURL(config, path: "/api/v1/artist/\(artist.id)")
        let body = try JSONEncoder().encode(artist)
        _ = try await network.requestRaw(url: url, method: "PUT", headers: headers(for: config), body: body)
    }

    func updateLidarrAlbum(_ config: ServerConfig, album: LidarrAlbum) async throws {
        let url = try makeURL(config, path: "/api/v1/album/\(album.id)")
        let body = try JSONEncoder().encode(album)
        _ = try await network.requestRaw(url: url, method: "PUT", headers: headers(for: config), body: body)
    }

    func updateRadarrMovie(_ config: ServerConfig, movie: RadarrMovie) async throws {
        let url = try makeURL(config, path: "/api/v3/movie/\(movie.id)")
        let body = try JSONEncoder().encode(movie)
        _ = try await network.requestRaw(url: url, method: "PUT", headers: headers(for: config), body: body)
    }

    func addRadarrMovie(_ config: ServerConfig, movie: Data) async throws {
        let url = try makeURL(config, path: "/api/v3/movie")
        _ = try await network.requestRaw(url: url, method: "POST", headers: headers(for: config), body: movie)
    }

    func addSonarrSeries(_ config: ServerConfig, series: Data) async throws {
        let url = try makeURL(config, path: "/api/v3/series")
        _ = try await network.requestRaw(url: url, method: "POST", headers: headers(for: config), body: series)
    }

    func addLidarrArtist(_ config: ServerConfig, artist: Data) async throws {
        let url = try makeURL(config, path: "/api/v1/artist")
        _ = try await network.requestRaw(url: url, method: "POST", headers: headers(for: config), body: artist)
    }

    // MARK: - Release (Manual Search)

    func fetchRadarrReleases(_ config: ServerConfig, movieId: Int) async throws -> [ArrRelease] {
        let url = try makeURL(config, path: "/api/v3/release", queryItems: [URLQueryItem(name: "movieId", value: String(movieId))])
        return try await network.request(url: url, headers: headers(for: config))
    }

    func fetchSonarrEpisodeReleases(_ config: ServerConfig, episodeId: Int) async throws -> [ArrRelease] {
        let url = try makeURL(config, path: "/api/v3/release",
                              queryItems: [URLQueryItem(name: "episodeId", value: String(episodeId))])
        return try await network.request(url: url, headers: headers(for: config))
    }

    func fetchSonarrReleases(_ config: ServerConfig, seriesId: Int, seasonNumber: Int? = nil) async throws -> [ArrRelease] {
        var queryItems = [URLQueryItem(name: "seriesId", value: String(seriesId))]
        if let seasonNumber {
            queryItems.append(URLQueryItem(name: "seasonNumber", value: String(seasonNumber)))
        }
        let url = try makeURL(config, path: "/api/v3/release", queryItems: queryItems)
        return try await network.request(url: url, headers: headers(for: config))
    }

    func fetchLidarrReleases(_ config: ServerConfig, albumId: Int) async throws -> [ArrRelease] {
        let url = try makeURL(config, path: "/api/v1/release", queryItems: [URLQueryItem(name: "albumId", value: String(albumId))])
        return try await network.request(url: url, headers: headers(for: config))
    }

    func grabRadarrRelease(_ config: ServerConfig, guid: String, indexerId: Int) async throws {
        let url = try makeURL(config, path: "/api/v3/release")
        let body = try JSONEncoder().encode(ReleaseGrabRequest(guid: guid, indexerId: indexerId))
        _ = try await network.requestRaw(url: url, method: "POST", headers: headers(for: config), body: body)
    }

    func grabSonarrRelease(_ config: ServerConfig, guid: String, indexerId: Int) async throws {
        let url = try makeURL(config, path: "/api/v3/release")
        let body = try JSONEncoder().encode(ReleaseGrabRequest(guid: guid, indexerId: indexerId))
        _ = try await network.requestRaw(url: url, method: "POST", headers: headers(for: config), body: body)
    }

    func grabLidarrRelease(_ config: ServerConfig, guid: String, indexerId: Int) async throws {
        let url = try makeURL(config, path: "/api/v1/release")
        let body = try JSONEncoder().encode(ReleaseGrabRequest(guid: guid, indexerId: indexerId))
        _ = try await network.requestRaw(url: url, method: "POST", headers: headers(for: config), body: body)
    }
}
