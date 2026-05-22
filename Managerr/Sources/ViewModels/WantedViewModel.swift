import Foundation

@MainActor
@Observable
final class WantedViewModel {
    var items: [WantedItem] = []
    var isLoading = false
    var errorMessages: [ServerConfig.ServiceType: String] = [:]
    var filter: WantedFilter = .missing
    let service: ServerConfig.ServiceType

    init(service: ServerConfig.ServiceType) {
        self.service = service
    }

    func fetch(_ settings: SettingsStore) async {
        isLoading = true
        var fetched: [WantedItem] = []
        var errors: [ServerConfig.ServiceType: String] = [:]

        let config = settings.config(for: service)
        let currentFilter = filter

        do {
            let newItems: [WantedItem]
            switch service {
            case .radarr:
                let records = try await ArrService.shared.fetchRadarrWanted(config, filter: currentFilter)
                newItems = records.map { WantedItem(service: .radarr, content: .movie($0)) }
            case .sonarr:
                let records = try await ArrService.shared.fetchSonarrWanted(config, filter: currentFilter)
                newItems = records.map { WantedItem(service: .sonarr, content: .episode($0)) }
            case .lidarr:
                let records = try await ArrService.shared.fetchLidarrWanted(config, filter: currentFilter)
                newItems = records.map { WantedItem(service: .lidarr, content: .album($0)) }
            case .transmission:
                newItems = []
            }
            fetched = newItems
        } catch {
            errors[service] = error.localizedDescription
        }

        items = fetched
        errorMessages = errors
        isLoading = false
    }

    func autoSearch(_ settings: SettingsStore, item: WantedItem) async {
        let config = settings.config(for: service)
        do {
            switch item.content {
            case .movie(let m):
                try await ArrService.shared.commandRadarr(config, command: RadarrCommand(name: "MoviesSearch", movieIds: [m.id]))
            case .episode(let e):
                try await ArrService.shared.commandSonarr(config, command: SonarrCommand(name: "EpisodeSearch", episodeIds: [e.id]))
            case .album(let a):
                try await ArrService.shared.commandLidarr(config, command: LidarrCommand(name: "AlbumSearch", artistId: nil, albumIds: [a.id]))
            }
        } catch {
            errorMessages[service] = error.localizedDescription
        }
    }

    func unmonitor(_ settings: SettingsStore, item: WantedItem) async {
        let config = settings.config(for: service)
        do {
            switch item.content {
            case .movie(let m):
                try await ArrService.shared.setRadarrMovieMonitored(config, movie: m, monitored: false)
            case .episode(let e):
                try await ArrService.shared.setSonarrEpisodeMonitored(config, episode: e, monitored: false)
            case .album(let a):
                try await ArrService.shared.setLidarrAlbumMonitored(config, album: a, monitored: false)
            }
            items.removeAll { $0.id == item.id }
        } catch {
            errorMessages[service] = error.localizedDescription
        }
    }
}
