import Testing
@testable import Managerr

// SettingsStore reads/writes UserDefaults on init and save().
// Tests work by calling updateConfig() to set a known state, then checking isConfigured().
// updateConfig() mutates self.configs directly before saving, so the logic under
// test (isConfigured) is exercised without depending on UserDefaults state.

@MainActor
struct SettingsStoreTests {

    // MARK: - Arr services require isEnabled + url + apiKey

    @Test func isConfigured_radarr_allFieldsPresent_returnsTrue() {
        let store = SettingsStore()
        store.updateConfig(ServerConfig(url: "http://localhost:7878", apiKey: "abc123", isEnabled: true, serviceType: .radarr))
        #expect(store.isConfigured(.radarr) == true)
    }

    @Test func isConfigured_sonarr_allFieldsPresent_returnsTrue() {
        let store = SettingsStore()
        store.updateConfig(ServerConfig(url: "http://localhost:8989", apiKey: "abc123", isEnabled: true, serviceType: .sonarr))
        #expect(store.isConfigured(.sonarr) == true)
    }

    @Test func isConfigured_lidarr_allFieldsPresent_returnsTrue() {
        let store = SettingsStore()
        store.updateConfig(ServerConfig(url: "http://localhost:8686", apiKey: "abc123", isEnabled: true, serviceType: .lidarr))
        #expect(store.isConfigured(.lidarr) == true)
    }

    @Test func isConfigured_radarr_notEnabled_returnsFalse() {
        let store = SettingsStore()
        store.updateConfig(ServerConfig(url: "http://localhost:7878", apiKey: "abc123", isEnabled: false, serviceType: .radarr))
        #expect(store.isConfigured(.radarr) == false)
    }

    @Test func isConfigured_radarr_emptyURL_returnsFalse() {
        let store = SettingsStore()
        store.updateConfig(ServerConfig(url: "", apiKey: "abc123", isEnabled: true, serviceType: .radarr))
        #expect(store.isConfigured(.radarr) == false)
    }

    @Test func isConfigured_radarr_emptyAPIKey_returnsFalse() {
        let store = SettingsStore()
        store.updateConfig(ServerConfig(url: "http://localhost:7878", apiKey: "", isEnabled: true, serviceType: .radarr))
        #expect(store.isConfigured(.radarr) == false)
    }

    // MARK: - Transmission does NOT require an API key

    @Test func isConfigured_transmission_noAPIKey_returnsTrue() {
        let store = SettingsStore()
        store.updateConfig(ServerConfig(url: "http://localhost:9091", apiKey: "", isEnabled: true, serviceType: .transmission))
        #expect(store.isConfigured(.transmission) == true)
    }

    @Test func isConfigured_transmission_withAPIKey_returnsTrue() {
        let store = SettingsStore()
        store.updateConfig(ServerConfig(url: "http://localhost:9091", apiKey: "user:pass", isEnabled: true, serviceType: .transmission))
        #expect(store.isConfigured(.transmission) == true)
    }

    @Test func isConfigured_transmission_notEnabled_returnsFalse() {
        let store = SettingsStore()
        store.updateConfig(ServerConfig(url: "http://localhost:9091", apiKey: "", isEnabled: false, serviceType: .transmission))
        #expect(store.isConfigured(.transmission) == false)
    }

    @Test func isConfigured_transmission_emptyURL_returnsFalse() {
        let store = SettingsStore()
        store.updateConfig(ServerConfig(url: "", apiKey: "", isEnabled: true, serviceType: .transmission))
        #expect(store.isConfigured(.transmission) == false)
    }

    // MARK: - Each service type is checked independently

    @Test func isConfigured_configuredServiceDoesNotAffectOthers() {
        let store = SettingsStore()
        // Explicitly set all services to a known state so UserDefaults from
        // other test runs doesn't interfere.
        store.updateConfig(ServerConfig(url: "http://localhost:7878", apiKey: "key", isEnabled: true,  serviceType: .radarr))
        store.updateConfig(ServerConfig(url: "http://localhost:8989", apiKey: "",    isEnabled: false, serviceType: .sonarr))
        store.updateConfig(ServerConfig(url: "http://localhost:8686", apiKey: "",    isEnabled: false, serviceType: .lidarr))
        store.updateConfig(ServerConfig(url: "http://localhost:9091", apiKey: "",    isEnabled: false, serviceType: .transmission))
        #expect(store.isConfigured(.radarr) == true)
        #expect(store.isConfigured(.sonarr) == false)
        #expect(store.isConfigured(.lidarr) == false)
        #expect(store.isConfigured(.transmission) == false)
    }
}
