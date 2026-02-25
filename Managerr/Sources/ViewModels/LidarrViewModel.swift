import Foundation

@Observable
final class LidarrViewModel {
    var artists: [LidarrArtist] = []
    var albums: [LidarrAlbum] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var searchText: String = ""
    var viewMode: ViewMode = .artists
    var sortOrder: SortOrder = .alphabetical

    enum ViewMode: String, CaseIterable {
        case artists = "Artists"
        case albums = "Albums"
    }

    enum SortOrder: String, CaseIterable {
        case alphabetical = "A-Z"
        case dateAdded = "Date Added"
        case year = "Year"
    }

    var filteredAlbums: [LidarrAlbum] {
        let filtered: [LidarrAlbum]
        if searchText.isEmpty {
            filtered = albums
        } else {
            filtered = albums.filter {
                ($0.title ?? "").localizedStandardContains(searchText) ||
                ($0.artist?.artistName ?? "").localizedStandardContains(searchText)
            }
        }

        switch sortOrder {
        case .alphabetical:
            return filtered.sorted { ($0.title ?? "") < ($1.title ?? "") }
        case .dateAdded:
            return filtered.sorted { ($0.releaseDate ?? "") > ($1.releaseDate ?? "") }
        case .year:
            return filtered.sorted { ($0.releaseDate ?? "") > ($1.releaseDate ?? "") }
        }
    }

    var filteredArtists: [LidarrArtist] {
        let filtered: [LidarrArtist]
        if searchText.isEmpty {
            filtered = artists
        } else {
            filtered = artists.filter { ($0.artistName ?? "").localizedStandardContains(searchText) }
        }

        switch sortOrder {
        case .alphabetical:
            return filtered.sorted { ($0.sortName ?? $0.artistName ?? "") < ($1.sortName ?? $1.artistName ?? "") }
        case .dateAdded:
            return filtered.sorted { ($0.added ?? "") > ($1.added ?? "") }
        case .year:
            return filtered.sorted { ($0.added ?? "") > ($1.added ?? "") }
        }
    }

    func fetchAll(_ config: ServerConfig) async {
        isLoading = true
        errorMessage = nil
        do {
            async let fetchedArtists = ArrService.shared.fetchLidarrArtists(config)
            async let fetchedAlbums = ArrService.shared.fetchLidarrAlbums(config)
            artists = try await fetchedArtists
            albums = try await fetchedAlbums
            let artistURLs = artists.compactMap { $0.posterURL(config: config) }
            let albumURLs = albums.compactMap { $0.coverURL(config: config) }
            Task { await ImageLoader.shared.prefetch(urls: artistURLs + albumURLs) }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func deleteArtist(_ config: ServerConfig, artist: LidarrArtist) async {
        do {
            try await ArrService.shared.deleteLidarrArtist(config, id: artist.id)
            artists.removeAll { $0.id == artist.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func searchArtist(_ config: ServerConfig, artistId: Int) async {
        do {
            let command = LidarrCommand(name: "ArtistSearch", artistId: artistId, albumIds: nil)
            try await ArrService.shared.commandLidarr(config, command: command)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func searchAlbum(_ config: ServerConfig, albumId: Int) async {
        do {
            let command = LidarrCommand(name: "AlbumSearch", artistId: nil, albumIds: [albumId])
            try await ArrService.shared.commandLidarr(config, command: command)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func toggleArtistMonitored(_ config: ServerConfig, artist: LidarrArtist) async -> Bool {
        do {
            let data = try JSONEncoder().encode(artist)
            var dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            dict["monitored"] = !artist.monitored
            let body = try JSONSerialization.data(withJSONObject: dict)
            guard let baseURL = config.baseURL else { throw NetworkError.invalidURL }
            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
            components?.path = "/api/v1/artist/\(artist.id)"
            guard let url = components?.url else { throw NetworkError.invalidURL }
            let responseData = try await NetworkService.shared.requestRaw(url: url, method: "PUT", headers: ["X-Api-Key": config.apiKey, "Accept": "application/json"], body: body)
            let updated = try JSONDecoder().decode(LidarrArtist.self, from: responseData)
            if let index = artists.firstIndex(where: { $0.id == artist.id }) {
                artists[index] = updated
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func toggleAlbumMonitored(_ config: ServerConfig, album: LidarrAlbum) async -> Bool {
        do {
            let data = try JSONEncoder().encode(album)
            var dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            dict["monitored"] = !album.monitored
            let body = try JSONSerialization.data(withJSONObject: dict)
            guard let baseURL = config.baseURL else { throw NetworkError.invalidURL }
            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
            components?.path = "/api/v1/album/\(album.id)"
            guard let url = components?.url else { throw NetworkError.invalidURL }
            let responseData = try await NetworkService.shared.requestRaw(url: url, method: "PUT", headers: ["X-Api-Key": config.apiKey, "Accept": "application/json"], body: body)
            let updated = try JSONDecoder().decode(LidarrAlbum.self, from: responseData)
            if let index = albums.firstIndex(where: { $0.id == album.id }) {
                albums[index] = updated
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
