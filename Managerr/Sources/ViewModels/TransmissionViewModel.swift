import Foundation

@MainActor
@Observable
final class TransmissionViewModel {
    var torrents: [TransmissionTorrent] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var searchText: String = ""
    var filterStatus: FilterStatus = .all
    var sortOption: SortOption = .dateAdded
    var sortAscending: Bool = false
    var detailedTorrent: TransmissionTorrent?
    var peerCountries: [String: String] = [:]
    var altSpeedEnabled: Bool = false

    enum FilterStatus: String, CaseIterable {
        case all = "All"
        case downloading = "Downloading"
        case seeding = "Seeding"
        case stopped = "Stopped"
    }

    enum SortOption: String, CaseIterable {
        case name = "Name"
        case dateAdded = "Date Added"
        case size = "Size"
        case progress = "Progress"
        case ratio = "Ratio"
        case speed = "Speed"
    }

    var filteredTorrents: [TransmissionTorrent] {
        var result = torrents

        if !searchText.isEmpty {
            result = result.filter { ($0.name ?? "").localizedStandardContains(searchText) }
        }

        switch filterStatus {
        case .all: break
        case .downloading:
            result = result.filter { $0.status == 3 || $0.status == 4 }
        case .seeding:
            result = result.filter { $0.status == 5 || $0.status == 6 }
        case .stopped:
            result = result.filter { $0.status == 0 }
        }

        result.sort { a, b in
            let ascending: Bool
            switch sortOption {
            case .name:
                ascending = (a.name ?? "").localizedStandardCompare(b.name ?? "") == .orderedAscending
            case .dateAdded:
                ascending = (a.addedDate ?? 0) < (b.addedDate ?? 0)
            case .size:
                ascending = (a.totalSize ?? 0) < (b.totalSize ?? 0)
            case .progress:
                ascending = (a.percentDone ?? 0) < (b.percentDone ?? 0)
            case .ratio:
                ascending = (a.uploadRatio ?? -1) < (b.uploadRatio ?? -1)
            case .speed:
                ascending = (a.rateDownload ?? 0) < (b.rateDownload ?? 0)
            }
            return sortAscending ? ascending : !ascending
        }
        return result
    }

    var totalDownloadSpeed: Int64 {
        torrents.reduce(0) { $0 + ($1.rateDownload ?? 0) }
    }

    var totalUploadSpeed: Int64 {
        torrents.reduce(0) { $0 + ($1.rateUpload ?? 0) }
    }

    func fetchTorrents(_ config: ServerConfig) async {
        isLoading = true
        errorMessage = nil
        do {
            torrents = try await TransmissionService.shared.fetchTorrents(config)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func fetchTorrentsSilently(_ config: ServerConfig) async {
        guard !isLoading else { return }
        do {
            torrents = try await TransmissionService.shared.fetchTorrents(config)
            errorMessage = nil
        } catch {
            // Keep last known data; don't overwrite error state on background failures
        }
    }

    func setSortOption(_ option: SortOption) {
        if sortOption == option { sortAscending.toggle() } else { sortOption = option }
    }

    func fetchSession(_ config: ServerConfig) async {
        do {
            let session = try await TransmissionService.shared.fetchSession(config)
            altSpeedEnabled = session.altSpeedEnabled ?? false
        } catch {}
    }

    func toggleAltSpeed(_ config: ServerConfig) async {
        altSpeedEnabled.toggle()
        do {
            try await TransmissionService.shared.setAltSpeedEnabled(config, enabled: altSpeedEnabled)
        } catch {
            altSpeedEnabled.toggle()
        }
    }

    func fetchTorrentDetail(_ config: ServerConfig, id: Int, showFlags: Bool = true) async {
        do {
            detailedTorrent = try await TransmissionService.shared.fetchTorrentDetail(config, id: id)
            if showFlags, let peers = detailedTorrent?.peers {
                await lookupPeerCountries(peers)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startTorrent(_ config: ServerConfig, id: Int) async {
        do {
            try await TransmissionService.shared.startTorrent(config, ids: [id])
            await fetchTorrents(config)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopTorrent(_ config: ServerConfig, id: Int) async {
        do {
            try await TransmissionService.shared.stopTorrent(config, ids: [id])
            await fetchTorrents(config)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeTorrent(_ config: ServerConfig, id: Int, deleteData: Bool) async {
        do {
            try await TransmissionService.shared.removeTorrent(config, ids: [id], deleteData: deleteData)
            torrents.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addTorrent(_ config: ServerConfig, url: String) async {
        do {
            try await TransmissionService.shared.addTorrent(config, url: url)
            await fetchTorrents(config)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addTorrentFile(_ config: ServerConfig, data: Data) async {
        do {
            try await TransmissionService.shared.addTorrentFile(config, data: data)
            await fetchTorrents(config)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func verifyTorrent(_ config: ServerConfig, id: Int) async {
        do {
            try await TransmissionService.shared.verifyTorrent(config, ids: [id])
            await fetchTorrents(config)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reannounceTorrent(_ config: ServerConfig, id: Int) async {
        do {
            try await TransmissionService.shared.reannounce(config, ids: [id])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startSelected(_ config: ServerConfig, ids: Set<Int>) async {
        let stoppedIDs = torrents.filter { ids.contains($0.id) && $0.status == 0 }.map(\.id)
        guard !stoppedIDs.isEmpty else { return }
        do {
            try await TransmissionService.shared.startTorrent(config, ids: stoppedIDs)
            await fetchTorrents(config)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopSelected(_ config: ServerConfig, ids: Set<Int>) async {
        let activeIDs = torrents.filter { ids.contains($0.id) && $0.isActive }.map(\.id)
        guard !activeIDs.isEmpty else { return }
        do {
            try await TransmissionService.shared.stopTorrent(config, ids: activeIDs)
            await fetchTorrents(config)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeSelected(_ config: ServerConfig, ids: Set<Int>, deleteData: Bool) async {
        do {
            try await TransmissionService.shared.removeTorrent(config, ids: Array(ids), deleteData: deleteData)
            torrents.removeAll { ids.contains($0.id) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startAll(_ config: ServerConfig) async {
        let ids = torrents.filter { $0.status == 0 }.map(\.id)
        guard !ids.isEmpty else { return }
        do {
            try await TransmissionService.shared.startTorrent(config, ids: ids)
            await fetchTorrents(config)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopAll(_ config: ServerConfig) async {
        let ids = torrents.filter { $0.isActive }.map(\.id)
        guard !ids.isEmpty else { return }
        do {
            try await TransmissionService.shared.stopTorrent(config, ids: ids)
            await fetchTorrents(config)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func lookupPeerCountries(_ peers: [TransmissionPeer]) async {
        let unknownAddresses = peers.compactMap(\.address).filter { peerCountries[$0] == nil }
        let batches = stride(from: 0, to: unknownAddresses.count, by: 10).map {
            Array(unknownAddresses[$0 ..< min($0 + 10, unknownAddresses.count)])
        }
        for (index, batch) in batches.enumerated() {
            await withTaskGroup(of: (String, String)?.self) { group in
                for address in batch {
                    group.addTask { [self] in await self.fetchCountry(for: address) }
                }
                for await result in group {
                    if let (ip, country) = result {
                        peerCountries[ip] = country
                    }
                }
            }
            if index < batches.count - 1 {
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private nonisolated func fetchCountry(for ip: String) async -> (String, String)? {
        guard let url = URL(string: "https://api.country.is/\(ip)") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(CountryResponse.self, from: data)
            if let country = response.country {
                return (ip, country)
            }
        } catch {}
        return nil
    }
}
