import Foundation

@Observable
final class SettingsStore {
    var configs: [ServerConfig]
    var defaultTab: TabSelection
    var showPeerFlags: Bool

    private let configsKey = "serverConfigs"
    private let defaultTabKey = "defaultTab"
    private let showPeerFlagsKey = "showPeerFlags"

    init() {
        if let data = UserDefaults.standard.data(forKey: configsKey),
           let decoded = try? JSONDecoder().decode([ServerConfig].self, from: data) {
            // Filter out any legacy service types (e.g. tmdb) that no longer exist
            configs = decoded.filter { ServerConfig.ServiceType.allCases.contains($0.serviceType) }
        } else {
            configs = ServerConfig.ServiceType.allCases.map { ServerConfig.defaultConfig(for: $0) }
        }

        if let raw = UserDefaults.standard.string(forKey: defaultTabKey),
           let tab = TabSelection(rawValue: raw) {
            defaultTab = tab
        } else {
            defaultTab = .movies
        }

        showPeerFlags = UserDefaults.standard.object(forKey: "showPeerFlags") as? Bool ?? true
        
        // Ensure all current service types have a config
        for type in ServerConfig.ServiceType.allCases {
            if !configs.contains(where: { $0.serviceType == type }) {
                configs.append(ServerConfig.defaultConfig(for: type))
            }
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(configs) {
            UserDefaults.standard.set(data, forKey: configsKey)
        }
        UserDefaults.standard.set(defaultTab.rawValue, forKey: defaultTabKey)
        UserDefaults.standard.set(showPeerFlags, forKey: showPeerFlagsKey)
    }

    func config(for type: ServerConfig.ServiceType) -> ServerConfig {
        configs.first(where: { $0.serviceType == type }) ?? ServerConfig.defaultConfig(for: type)
    }

    func updateConfig(_ config: ServerConfig) {
        if let index = configs.firstIndex(where: { $0.serviceType == config.serviceType }) {
            configs[index] = config
        }
        save()
    }

    func isConfigured(_ type: ServerConfig.ServiceType) -> Bool {
        let c = config(for: type)
        return c.isEnabled && !c.url.isEmpty && (type == .transmission || !c.apiKey.isEmpty)
    }
}
