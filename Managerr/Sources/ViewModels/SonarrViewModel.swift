import Foundation

@Observable
final class SonarrViewModel {
    var series: [SonarrSeries] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var searchText: String = ""
    var sortOrder: SortOrder = .alphabetical

    enum SortOrder: String, CaseIterable {
        case alphabetical = "A-Z"
        case year = "Year"
        case dateAdded = "Date Added"
        case network = "Network"
    }

    var filteredSeries: [SonarrSeries] {
        let filtered: [SonarrSeries]
        if searchText.isEmpty {
            filtered = series
        } else {
            filtered = series.filter { $0.title.localizedStandardContains(searchText) }
        }

        switch sortOrder {
        case .alphabetical:
            return filtered.sorted { ($0.sortTitle ?? $0.title) < ($1.sortTitle ?? $1.title) }
        case .year:
            return filtered.sorted { ($0.year ?? 0) > ($1.year ?? 0) }
        case .dateAdded:
            return filtered.sorted { ($0.added ?? "") > ($1.added ?? "") }
        case .network:
            return filtered.sorted { ($0.network ?? "") < ($1.network ?? "") }
        }
    }

    func fetchSeries(_ config: ServerConfig) async {
        isLoading = true
        errorMessage = nil
        do {
            series = try await ArrService.shared.fetchSonarrSeries(config)
            let baseURL = config.baseURL
            let urls = series.compactMap { $0.posterURL(baseURL: baseURL) }
            Task { await ImageLoader.shared.prefetch(urls: urls) }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func deleteSeries(_ config: ServerConfig, show: SonarrSeries, deleteFiles: Bool) async {
        do {
            try await ArrService.shared.deleteSonarrSeries(config, id: show.id, deleteFiles: deleteFiles)
            series.removeAll { $0.id == show.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func searchSeries(_ config: ServerConfig, seriesId: Int) async {
        do {
            let command = SonarrCommand(name: "SeriesSearch", seriesId: seriesId)
            try await ArrService.shared.commandSonarr(config, command: command)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func searchSeason(_ config: ServerConfig, seriesId: Int, seasonNumber: Int) async {
        try? await ArrService.shared.commandSonarr(
            config,
            command: SonarrCommand(name: "SeasonSearch", seriesId: seriesId, seasonNumber: seasonNumber)
        )
    }

    func searchEpisode(_ config: ServerConfig, episodeId: Int) async {
        try? await ArrService.shared.commandSonarr(
            config,
            command: SonarrCommand(name: "EpisodeSearch", episodeIds: [episodeId])
        )
    }

    @discardableResult
    func toggleMonitored(_ config: ServerConfig, show: SonarrSeries) async -> Bool {
        do {
            let data = try JSONEncoder().encode(show)
            var dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            dict["monitored"] = !show.monitored
            let body = try JSONSerialization.data(withJSONObject: dict)
            let url = try makeSeriesURL(config, id: show.id)
            let responseData = try await NetworkService.shared.requestRaw(url: url, method: "PUT", headers: ["X-Api-Key": config.apiKey, "Accept": "application/json"], body: body)
            let updated = try JSONDecoder().decode(SonarrSeries.self, from: responseData)
            if let index = series.firstIndex(where: { $0.id == show.id }) {
                series[index] = updated
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func makeSeriesURL(_ config: ServerConfig, id: Int) throws -> URL {
        guard let baseURL = config.baseURL else { throw NetworkError.invalidURL }
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path = "/api/v3/series/\(id)"
        guard let url = components?.url else { throw NetworkError.invalidURL }
        return url
    }
}
