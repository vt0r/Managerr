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
    var items: [ArrQueueItem] = []
    var isLoading = false
    var errorMessages: [ServerConfig.ServiceType: String] = [:]
    var serviceFilter: ServerConfig.ServiceType? = nil
    var statusFilter: QueueStatusFilter = .all

    var filteredItems: [ArrQueueItem] {
        items.filter { item in
            let matchesService = serviceFilter == nil || item.serviceType == serviceFilter
            let matchesStatus: Bool
            switch statusFilter {
            case .all:
                matchesStatus = true
            case .active:
                let s = item.record.status?.lowercased()
                matchesStatus = ["downloading", "queued", "importing", "importpending", "delay"].contains(s)
            case .warning:
                matchesStatus = item.record.hasWarning
            case .error:
                matchesStatus = item.record.hasError
            }
            return matchesService && matchesStatus
        }
    }

    var isFiltered: Bool { serviceFilter != nil || statusFilter != .all }

    func fetch(_ settings: SettingsStore) async {
        isLoading = true
        var allItems: [ArrQueueItem] = []
        var errors: [ServerConfig.ServiceType: String] = [:]

        await withTaskGroup(of: (ServerConfig.ServiceType, [ArrQueueRecord], String?).self) { group in
            if settings.isConfigured(.radarr) {
                group.addTask {
                    do {
                        let records = try await ArrService.shared.fetchRadarrQueue(settings.config(for: .radarr))
                        return (.radarr, records, nil)
                    } catch {
                        return (.radarr, [], error.localizedDescription)
                    }
                }
            }
            if settings.isConfigured(.sonarr) {
                group.addTask {
                    do {
                        let records = try await ArrService.shared.fetchSonarrQueue(settings.config(for: .sonarr))
                        return (.sonarr, records, nil)
                    } catch {
                        return (.sonarr, [], error.localizedDescription)
                    }
                }
            }
            if settings.isConfigured(.lidarr) {
                group.addTask {
                    do {
                        let records = try await ArrService.shared.fetchLidarrQueue(settings.config(for: .lidarr))
                        return (.lidarr, records, nil)
                    } catch {
                        return (.lidarr, [], error.localizedDescription)
                    }
                }
            }

            for await (serviceType, records, errorMsg) in group {
                if let errorMsg {
                    errors[serviceType] = errorMsg
                } else {
                    allItems += records.map { ArrQueueItem(serviceType: serviceType, record: $0) }
                }
            }
        }

        items = allItems.sorted { statusSortOrder($0.record.status) < statusSortOrder($1.record.status) }
        errorMessages = errors
        isLoading = false
    }

    func removeItem(_ settings: SettingsStore, item: ArrQueueItem, blacklist: Bool) async {
        do {
            switch item.serviceType {
            case .radarr:
                try await ArrService.shared.removeRadarrQueueItem(settings.config(for: .radarr), id: item.record.id, blacklist: blacklist)
            case .sonarr:
                try await ArrService.shared.removeSonarrQueueItem(settings.config(for: .sonarr), id: item.record.id, blacklist: blacklist)
            case .lidarr:
                try await ArrService.shared.removeLidarrQueueItem(settings.config(for: .lidarr), id: item.record.id, blacklist: blacklist)
            case .transmission:
                break
            }
            items.removeAll { $0.id == item.id }
        } catch {}
    }

    func grabItem(_ settings: SettingsStore, item: ArrQueueItem) async {
        do {
            switch item.serviceType {
            case .radarr:
                try await ArrService.shared.grabRadarrQueueItem(settings.config(for: .radarr), id: item.record.id)
            case .sonarr:
                try await ArrService.shared.grabSonarrQueueItem(settings.config(for: .sonarr), id: item.record.id)
            case .lidarr:
                try await ArrService.shared.grabLidarrQueueItem(settings.config(for: .lidarr), id: item.record.id)
            case .transmission:
                break
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
