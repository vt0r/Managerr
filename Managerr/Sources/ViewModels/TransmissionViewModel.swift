import Foundation

@MainActor
@Observable
final class TransmissionViewModel {
    var torrents: [TransmissionTorrent] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var searchText: String = ""
    var filterStatus: FilterStatus = .all
    var detailedTorrent: TransmissionTorrent?
    var peerCountries: [String: String] = [:]

    enum FilterStatus: String, CaseIterable {
        case all = "All"
        case downloading = "Downloading"
        case seeding = "Seeding"
        case stopped = "Stopped"
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

        return result.sorted { ($0.addedDate ?? 0) > ($1.addedDate ?? 0) }
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
