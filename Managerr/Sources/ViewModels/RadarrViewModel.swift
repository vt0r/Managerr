import Foundation

@Observable
final class RadarrViewModel {
    var movies: [RadarrMovie] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var searchText: String = ""
    var sortOrder: SortOrder = .alphabetical

    enum SortOrder: String, CaseIterable {
        case alphabetical = "A-Z"
        case year = "Year"
        case dateAdded = "Date Added"
        case size = "Size"
    }

    var filteredMovies: [RadarrMovie] {
        let filtered: [RadarrMovie]
        if searchText.isEmpty {
            filtered = movies
        } else {
            filtered = movies.filter { $0.title.localizedStandardContains(searchText) }
        }

        switch sortOrder {
        case .alphabetical:
            return filtered.sorted { ($0.sortTitle ?? $0.title) < ($1.sortTitle ?? $1.title) }
        case .year:
            return filtered.sorted { ($0.year ?? 0) > ($1.year ?? 0) }
        case .dateAdded:
            return filtered.sorted { ($0.added ?? "") > ($1.added ?? "") }
        case .size:
            return filtered.sorted { ($0.sizeOnDisk ?? 0) > ($1.sizeOnDisk ?? 0) }
        }
    }

    func fetchMovies(_ config: ServerConfig) async {
        isLoading = true
        errorMessage = nil
        do {
            movies = try await ArrService.shared.fetchRadarrMovies(config)
            let baseURL = config.baseURL
            let urls = movies.compactMap { $0.posterURL(baseURL: baseURL) }
            Task { await ImageLoader.shared.prefetch(urls: urls) }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func deleteMovie(_ config: ServerConfig, movie: RadarrMovie, deleteFiles: Bool) async {
        do {
            try await ArrService.shared.deleteRadarrMovie(config, id: movie.id, deleteFiles: deleteFiles)
            movies.removeAll { $0.id == movie.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func searchMovie(_ config: ServerConfig, movieId: Int) async {
        do {
            let command = RadarrCommand(name: "MoviesSearch", movieIds: [movieId])
            try await ArrService.shared.commandRadarr(config, command: command)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func toggleMonitored(_ config: ServerConfig, movie: RadarrMovie) async -> Bool {
        do {
            let data = try JSONEncoder().encode(movie)
            var dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            dict["monitored"] = !movie.monitored
            let body = try JSONSerialization.data(withJSONObject: dict)
            guard let baseURL = config.baseURL else { throw NetworkError.invalidURL }
            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
            components?.path = "/api/v3/movie/\(movie.id)"
            guard let url = components?.url else { throw NetworkError.invalidURL }
            let responseData = try await NetworkService.shared.requestRaw(url: url, method: "PUT", headers: ["X-Api-Key": config.apiKey, "Accept": "application/json"], body: body)
            let updated = try JSONDecoder().decode(RadarrMovie.self, from: responseData)
            if let index = movies.firstIndex(where: { $0.id == movie.id }) {
                movies[index] = updated
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
