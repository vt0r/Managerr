import Foundation

enum QueueStatusFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case active = "Active"
    case warning = "Warning"
    case error = "Error"
    var id: String { rawValue }
}

struct ArrQueueItem: Identifiable, Sendable {
    let serviceType: ServerConfig.ServiceType
    let record: ArrQueueRecord
    var id: String { "\(serviceType.rawValue)-\(record.id)" }
}

@MainActor
@Observable
final class QueueViewModel {
    let service: ServerConfig.ServiceType

    var items: [ArrQueueItem] = []
    var isLoading = false
    var errorMessages: [ServerConfig.ServiceType: String] = [:]
    var statusFilter: QueueStatusFilter = .all

    init(service: ServerConfig.ServiceType) {
        self.service = service
    }

    var filteredItems: [ArrQueueItem] {
        items.filter { item in
            switch statusFilter {
            case .all: return true
            case .active:
                let s = item.record.status?.lowercased()
                return ["downloading", "queued", "importing", "importpending", "delay"].contains(s)
            case .warning: return item.record.hasWarning
            case .error: return item.record.hasError
            }
        }
    }

    var isFiltered: Bool { statusFilter != .all }

    func fetch(_ settings: SettingsStore) async {
        isLoading = true
        var allItems: [ArrQueueItem] = []
        var errors: [ServerConfig.ServiceType: String] = [:]

        let config = settings.config(for: service)
        do {
            let records: [ArrQueueRecord]
            switch service {
            case .radarr:  records = try await ArrService.shared.fetchRadarrQueue(config)
            case .sonarr:  records = try await ArrService.shared.fetchSonarrQueue(config)
            case .lidarr:  records = try await ArrService.shared.fetchLidarrQueue(config)
            case .transmission: records = []
            }
            allItems = records.map { ArrQueueItem(serviceType: service, record: $0) }
        } catch {
            errors[service] = error.localizedDescription
        }

        items = allItems.sorted { statusSortOrder($0.record.status) < statusSortOrder($1.record.status) }
        errorMessages = errors
        isLoading = false
    }

    func removeItem(_ settings: SettingsStore, item: ArrQueueItem, blacklist: Bool) async {
        let config = settings.config(for: service)
        do {
            switch service {
            case .radarr: try await ArrService.shared.removeRadarrQueueItem(config, id: item.record.id, blacklist: blacklist)
            case .sonarr: try await ArrService.shared.removeSonarrQueueItem(config, id: item.record.id, blacklist: blacklist)
            case .lidarr: try await ArrService.shared.removeLidarrQueueItem(config, id: item.record.id, blacklist: blacklist)
            case .transmission: break
            }
            items.removeAll { $0.id == item.id }
        } catch {}
    }

    func grabItem(_ settings: SettingsStore, item: ArrQueueItem) async {
        let config = settings.config(for: service)
        do {
            switch service {
            case .radarr: try await ArrService.shared.grabRadarrQueueItem(config, id: item.record.id)
            case .sonarr: try await ArrService.shared.grabSonarrQueueItem(config, id: item.record.id)
            case .lidarr: try await ArrService.shared.grabLidarrQueueItem(config, id: item.record.id)
            case .transmission: break
            }
            await fetch(settings)
        } catch {}
    }

    private func statusSortOrder(_ status: String?) -> Int {
        switch status?.lowercased() {
        case "downloading": return 0
        case "importpending": return 1
        case "importing": return 2
        case "queued": return 3
        case "paused": return 4
        case "delay": return 5
        case "downloadclientunavailable": return 6
        case "failedpending": return 7
        case "failed": return 8
        case "completed": return 9
        default: return 10
        }
    }
}
