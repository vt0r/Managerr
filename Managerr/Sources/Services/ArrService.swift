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

    func fetchRadarrTags(_ config: ServerConfig) async throws -> [ArrTag] {
        let url = try makeURL(config, path: "/api/v3/tag")
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

    func fetchSonarrTags(_ config: ServerConfig) async throws -> [ArrTag] {
        let url = try makeURL(config, path: "/api/v3/tag")
        return try await network.request(url: url, headers: headers(for: config))
    }

    func updateSonarrSeries(
        _ config: ServerConfig,
        series: SonarrSeries,
        qualityProfileId: Int,
        monitored: Bool,
        seriesType: String,
        rootFolderPath: String,
        tags: [Int],
        monitorNewItems: String,
        seasonFolder: Bool
    ) async throws {
        let url = try makeURL(config, path: "/api/v3/series/\(series.id)")
        let encoded = try JSONEncoder().encode(series)
        guard var dict = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else { return }
        dict["qualityProfileId"] = qualityProfileId
        dict["monitored"] = monitored
        dict["seriesType"] = seriesType
        dict["rootFolderPath"] = rootFolderPath
        dict["tags"] = tags
        dict["monitorNewItems"] = monitorNewItems
        dict["seasonFolder"] = seasonFolder
        let body = try JSONSerialization.data(withJSONObject: dict)
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

    func deleteSonarrEpisodeFile(_ config: ServerConfig, episodeFileId: Int) async throws {
        let url = try makeURL(config, path: "/api/v3/episodefile/\(episodeFileId)")
        _ = try await network.requestRaw(url: url, method: "DELETE", headers: headers(for: config))
    }

    func deleteSonarrSeasonFiles(_ config: ServerConfig, episodeFileIds: [Int]) async throws {
        struct Body: Encodable { let episodeFileIds: [Int] }
        let url = try makeURL(config, path: "/api/v3/episodefile/bulk")
        let body = try JSONEncoder().encode(Body(episodeFileIds: episodeFileIds))
        _ = try await network.requestRaw(url: url, method: "DELETE", headers: headers(for: config), body: body)
    }

    func deleteLidarrTrackFile(_ config: ServerConfig, trackFileId: Int) async throws {
        let url = try makeURL(config, path: "/api/v1/trackfile/\(trackFileId)")
        _ = try await network.requestRaw(url: url, method: "DELETE", headers: headers(for: config))
    }

    func deleteLidarrAlbumFiles(_ config: ServerConfig, trackFileIds: [Int]) async throws {
        struct Body: Encodable { let trackFileIds: [Int] }
        let url = try makeURL(config, path: "/api/v1/trackfile/bulk")
        let body = try JSONEncoder().encode(Body(trackFileIds: trackFileIds))
        _ = try await network.requestRaw(url: url, method: "DELETE", headers: headers(for: config), body: body)
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

    func fetchLidarrTags(_ config: ServerConfig) async throws -> [ArrTag] {
        let url = try makeURL(config, path: "/api/v1/tag")
        return try await network.request(url: url, headers: headers(for: config))
    }

    func fetchLidarrAlbumDetail(_ config: ServerConfig, albumId: Int) async throws -> LidarrAlbum {
        let url = try makeURL(config, path: "/api/v1/album/\(albumId)")
        return try await network.request(url: url, headers: headers(for: config))
    }

    func updateLidarrArtist(
        _ config: ServerConfig,
        artist: LidarrArtist,
        qualityProfileId: Int,
        metadataProfileId: Int,
        monitored: Bool,
        rootFolderPath: String,
        tags: [Int],
        monitorNewItems: String
    ) async throws {
        let url = try makeURL(config, path: "/api/v1/artist/\(artist.id)")
        let encoded = try JSONEncoder().encode(artist)
        guard var dict = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else { return }
        dict["qualityProfileId"] = qualityProfileId
        dict["metadataProfileId"] = metadataProfileId
        dict["monitored"] = monitored
        dict["rootFolderPath"] = rootFolderPath
        dict["tags"] = tags
        dict["monitorNewItems"] = monitorNewItems
        let body = try JSONSerialization.data(withJSONObject: dict)
        _ = try await network.requestRaw(url: url, method: "PUT", headers: headers(for: config), body: body)
    }

    func updateLidarrAlbum(
        _ config: ServerConfig,
        album: LidarrAlbum,
        monitored: Bool,
        anyReleaseOk: Bool,
        selectedReleaseId: Int?
    ) async throws {
        let url = try makeURL(config, path: "/api/v1/album/\(album.id)")
        let encoded = try JSONEncoder().encode(album)
        guard var dict = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else { return }
        dict["monitored"] = monitored
        dict["anyReleaseOk"] = anyReleaseOk
        if let selectedReleaseId, var releases = dict["releases"] as? [[String: Any]] {
            for i in releases.indices {
                releases[i]["monitored"] = (releases[i]["id"] as? Int == selectedReleaseId)
            }
            dict["releases"] = releases
        }
        let body = try JSONSerialization.data(withJSONObject: dict)
        _ = try await network.requestRaw(url: url, method: "PUT", headers: headers(for: config), body: body)
    }

    func updateRadarrMovie(
        _ config: ServerConfig,
        movie: RadarrMovie,
        qualityProfileId: Int,
        monitored: Bool,
        minimumAvailability: String,
        rootFolderPath: String,
        tags: [Int]
    ) async throws {
        let url = try makeURL(config, path: "/api/v3/movie/\(movie.id)")
        let encoded = try JSONEncoder().encode(movie)
        guard var dict = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else { return }
        dict["qualityProfileId"] = qualityProfileId
        dict["monitored"] = monitored
        dict["minimumAvailability"] = minimumAvailability
        dict["rootFolderPath"] = rootFolderPath
        dict["tags"] = tags
        let body = try JSONSerialization.data(withJSONObject: dict)
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

    // MARK: - Queue

    func fetchRadarrQueue(_ config: ServerConfig) async throws -> [ArrQueueRecord] {
        let url = try makeURL(config, path: "/api/v3/queue", queryItems: [
            URLQueryItem(name: "pageSize", value: "200"),
            URLQueryItem(name: "includeMovie", value: "true")
        ])
        let response: ArrQueueResponse = try await network.request(url: url, headers: headers(for: config))
        return response.records
    }

    func fetchSonarrQueue(_ config: ServerConfig) async throws -> [ArrQueueRecord] {
        let url = try makeURL(config, path: "/api/v3/queue", queryItems: [
            URLQueryItem(name: "pageSize", value: "200"),
            URLQueryItem(name: "includeSeries", value: "true"),
            URLQueryItem(name: "includeEpisode", value: "true")
        ])
        let response: ArrQueueResponse = try await network.request(url: url, headers: headers(for: config))
        return response.records
    }

    func fetchLidarrQueue(_ config: ServerConfig) async throws -> [ArrQueueRecord] {
        let url = try makeURL(config, path: "/api/v1/queue", queryItems: [
            URLQueryItem(name: "pageSize", value: "200"),
            URLQueryItem(name: "includeArtist", value: "true"),
            URLQueryItem(name: "includeAlbum", value: "true")
        ])
        let response: ArrQueueResponse = try await network.request(url: url, headers: headers(for: config))
        return response.records
    }

    func removeRadarrQueueItem(_ config: ServerConfig, id: Int, blacklist: Bool) async throws {
        let url = try makeURL(config, path: "/api/v3/queue/\(id)", queryItems: [
            URLQueryItem(name: "blacklist", value: String(blacklist)),
            URLQueryItem(name: "removeFromClient", value: "true")
        ])
        _ = try await network.requestRaw(url: url, method: "DELETE", headers: headers(for: config))
    }

    func removeSonarrQueueItem(_ config: ServerConfig, id: Int, blacklist: Bool) async throws {
        let url = try makeURL(config, path: "/api/v3/queue/\(id)", queryItems: [
            URLQueryItem(name: "blacklist", value: String(blacklist)),
            URLQueryItem(name: "removeFromClient", value: "true")
        ])
        _ = try await network.requestRaw(url: url, method: "DELETE", headers: headers(for: config))
    }

    func removeLidarrQueueItem(_ config: ServerConfig, id: Int, blacklist: Bool) async throws {
        let url = try makeURL(config, path: "/api/v1/queue/\(id)", queryItems: [
            URLQueryItem(name: "blacklist", value: String(blacklist)),
            URLQueryItem(name: "removeFromClient", value: "true")
        ])
        _ = try await network.requestRaw(url: url, method: "DELETE", headers: headers(for: config))
    }

    func grabRadarrQueueItem(_ config: ServerConfig, id: Int) async throws {
        let url = try makeURL(config, path: "/api/v3/queue/grab")
        let body = try JSONEncoder().encode(["ids": [id]])
        _ = try await network.requestRaw(url: url, method: "POST", headers: headers(for: config), body: body)
    }

    func grabSonarrQueueItem(_ config: ServerConfig, id: Int) async throws {
        let url = try makeURL(config, path: "/api/v3/queue/grab")
        let body = try JSONEncoder().encode(["ids": [id]])
        _ = try await network.requestRaw(url: url, method: "POST", headers: headers(for: config), body: body)
    }

    func grabLidarrQueueItem(_ config: ServerConfig, id: Int) async throws {
        let url = try makeURL(config, path: "/api/v1/queue/grab")
        let body = try JSONEncoder().encode(["ids": [id]])
        _ = try await network.requestRaw(url: url, method: "POST", headers: headers(for: config), body: body)
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

    func fetchLidarrArtistReleases(_ config: ServerConfig, artistId: Int) async throws -> [ArrRelease] {
        let url = try makeURL(config, path: "/api/v1/release", queryItems: [URLQueryItem(name: "artistId", value: String(artistId))])
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

    // MARK: - Wanted

    func fetchRadarrWanted(_ config: ServerConfig, filter: WantedFilter) async throws -> [RadarrMovie] {
        let url = try makeURL(config, path: "/api/v3/wanted/\(filter.endpoint)", queryItems: [
            URLQueryItem(name: "pageSize", value: "500"),
            URLQueryItem(name: "sortKey", value: "releaseDate"),
            URLQueryItem(name: "sortDirection", value: "descending")
        ])
        let response: WantedPageResponse<RadarrMovie> = try await network.request(url: url, headers: headers(for: config))
        return response.records
    }

    func fetchSonarrWanted(_ config: ServerConfig, filter: WantedFilter) async throws -> [SonarrEpisode] {
        let url = try makeURL(config, path: "/api/v3/wanted/\(filter.endpoint)", queryItems: [
            URLQueryItem(name: "pageSize", value: "500"),
            URLQueryItem(name: "sortKey", value: "airDateUtc"),
            URLQueryItem(name: "sortDirection", value: "descending"),
            URLQueryItem(name: "includeSeries", value: "true")
        ])
        let response: WantedPageResponse<SonarrEpisode> = try await network.request(url: url, headers: headers(for: config))
        return response.records
    }

    func fetchLidarrWanted(_ config: ServerConfig, filter: WantedFilter) async throws -> [LidarrAlbum] {
        let url = try makeURL(config, path: "/api/v1/wanted/\(filter.endpoint)", queryItems: [
            URLQueryItem(name: "pageSize", value: "500"),
            URLQueryItem(name: "sortKey", value: "releaseDate"),
            URLQueryItem(name: "sortDirection", value: "descending")
        ])
        let response: WantedPageResponse<LidarrAlbum> = try await network.request(url: url, headers: headers(for: config))
        return response.records
    }

    func setRadarrMovieMonitored(_ config: ServerConfig, movie: RadarrMovie, monitored: Bool) async throws {
        let url = try makeURL(config, path: "/api/v3/movie/\(movie.id)")
        let encoded = try JSONEncoder().encode(movie)
        guard var dict = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else { return }
        dict["monitored"] = monitored
        let body = try JSONSerialization.data(withJSONObject: dict)
        _ = try await network.requestRaw(url: url, method: "PUT", headers: headers(for: config), body: body)
    }

    func setSonarrEpisodeMonitored(_ config: ServerConfig, episode: SonarrEpisode, monitored: Bool) async throws {
        let url = try makeURL(config, path: "/api/v3/episode/\(episode.id)")
        let encoded = try JSONEncoder().encode(episode)
        guard var dict = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else { return }
        dict["monitored"] = monitored
        let body = try JSONSerialization.data(withJSONObject: dict)
        _ = try await network.requestRaw(url: url, method: "PUT", headers: headers(for: config), body: body)
    }

    func setLidarrAlbumMonitored(_ config: ServerConfig, album: LidarrAlbum, monitored: Bool) async throws {
        let url = try makeURL(config, path: "/api/v1/album/\(album.id)")
        let encoded = try JSONEncoder().encode(album)
        guard var dict = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else { return }
        dict["monitored"] = monitored
        let body = try JSONSerialization.data(withJSONObject: dict)
        _ = try await network.requestRaw(url: url, method: "PUT", headers: headers(for: config), body: body)
    }

    // MARK: - Calendar

    func fetchRadarrCalendar(_ config: ServerConfig, start: Date, end: Date, unmonitored: Bool = true) async throws -> [RadarrMovie] {
        let url = try makeURL(config, path: "/api/v3/calendar", queryItems: [
            URLQueryItem(name: "start", value: Self.calendarDate(start)),
            URLQueryItem(name: "end", value: Self.calendarDate(end)),
            URLQueryItem(name: "unmonitored", value: String(unmonitored))
        ])
        return try await network.request(url: url, headers: headers(for: config))
    }

    func fetchSonarrCalendar(_ config: ServerConfig, start: Date, end: Date, unmonitored: Bool = true) async throws -> [SonarrEpisode] {
        let url = try makeURL(config, path: "/api/v3/calendar", queryItems: [
            URLQueryItem(name: "start", value: Self.calendarDate(start)),
            URLQueryItem(name: "end", value: Self.calendarDate(end)),
            URLQueryItem(name: "unmonitored", value: String(unmonitored)),
            URLQueryItem(name: "includeSeries", value: "true")
        ])
        return try await network.request(url: url, headers: headers(for: config))
    }

    func fetchLidarrCalendar(_ config: ServerConfig, start: Date, end: Date, unmonitored: Bool = true) async throws -> [LidarrAlbum] {
        let url = try makeURL(config, path: "/api/v1/calendar", queryItems: [
            URLQueryItem(name: "start", value: Self.calendarDate(start)),
            URLQueryItem(name: "end", value: Self.calendarDate(end)),
            URLQueryItem(name: "unmonitored", value: String(unmonitored)),
            URLQueryItem(name: "includeArtist", value: "true")
        ])
        return try await network.request(url: url, headers: headers(for: config))
    }

    private static let calendarFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    private static func calendarDate(_ date: Date) -> String {
        calendarFormatter.string(from: date)
    }
}
