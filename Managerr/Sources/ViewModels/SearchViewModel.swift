import Foundation

@MainActor
@Observable
final class SearchViewModel {
    var searchText: String = ""
    var searchScope: SearchScope = .movies
    var movieResults: [RadarrMovie] = []
    var seriesResults: [SonarrSeries] = []
    var artistResults: [LidarrArtist] = []
    var isSearching: Bool = false
    var errorMessage: String?

    enum SearchScope: String, CaseIterable {
        case movies = "Movies"
        case tvShows = "TV Shows"
        case music = "Music"
    }

    func search(settings: SettingsStore) async {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        errorMessage = nil

        do {
            switch searchScope {
            case .movies:
                let config = settings.config(for: .radarr)
                guard settings.isConfigured(.radarr) else {
                    errorMessage = "Radarr not configured"
                    isSearching = false
                    return
                }
                movieResults = try await ArrService.shared.lookupRadarrMovie(config, term: searchText)
            case .tvShows:
                let config = settings.config(for: .sonarr)
                guard settings.isConfigured(.sonarr) else {
                    errorMessage = "Sonarr not configured"
                    isSearching = false
                    return
                }
                seriesResults = try await ArrService.shared.lookupSonarrSeries(config, term: searchText)
            case .music:
                let config = settings.config(for: .lidarr)
                guard settings.isConfigured(.lidarr) else {
                    errorMessage = "Lidarr not configured"
                    isSearching = false
                    return
                }
                artistResults = try await ArrService.shared.lookupLidarr(config, term: searchText)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isSearching = false
    }
}
