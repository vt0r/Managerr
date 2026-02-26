import Testing
import Foundation
@testable import Managerr

struct ServerConfigTests {

    // MARK: - displayName

    @Test func displayName_radarr() {
        #expect(ServerConfig.ServiceType.radarr.displayName == "Radarr")
    }

    @Test func displayName_sonarr() {
        #expect(ServerConfig.ServiceType.sonarr.displayName == "Sonarr")
    }

    @Test func displayName_lidarr() {
        #expect(ServerConfig.ServiceType.lidarr.displayName == "Lidarr")
    }

    @Test func displayName_transmission() {
        #expect(ServerConfig.ServiceType.transmission.displayName == "Transmission")
    }

    // MARK: - defaultPort

    @Test func defaultPort_radarr() {
        #expect(ServerConfig.ServiceType.radarr.defaultPort == 7878)
    }

    @Test func defaultPort_sonarr() {
        #expect(ServerConfig.ServiceType.sonarr.defaultPort == 8989)
    }

    @Test func defaultPort_lidarr() {
        #expect(ServerConfig.ServiceType.lidarr.defaultPort == 8686)
    }

    @Test func defaultPort_transmission() {
        #expect(ServerConfig.ServiceType.transmission.defaultPort == 9091)
    }

    // MARK: - credType

    @Test func credType_arrServices_returnsAPIKey() {
        #expect(ServerConfig.ServiceType.radarr.credType == "API Key")
        #expect(ServerConfig.ServiceType.sonarr.credType == "API Key")
        #expect(ServerConfig.ServiceType.lidarr.credType == "API Key")
    }

    @Test func credType_transmission_returnsCredentials() {
        #expect(ServerConfig.ServiceType.transmission.credType == "Credentials (user:pass)")
    }

    // MARK: - icon

    @Test func icon_radarr_isFilm() {
        #expect(ServerConfig.ServiceType.radarr.icon == "film")
    }

    @Test func icon_sonarr_isTV() {
        #expect(ServerConfig.ServiceType.sonarr.icon == "tv")
    }

    @Test func icon_lidarr_isMusicNote() {
        #expect(ServerConfig.ServiceType.lidarr.icon == "music.note")
    }

    @Test func icon_transmission_isDownloadCircle() {
        #expect(ServerConfig.ServiceType.transmission.icon == "arrow.down.circle")
    }

    // MARK: - defaultConfig

    @Test func defaultConfig_radarr_usesPort7878() {
        let config = ServerConfig.defaultConfig(for: .radarr)
        #expect(config.url == "http://localhost:7878")
        #expect(config.serviceType == .radarr)
        #expect(config.isEnabled == false)
        #expect(config.apiKey == "")
    }

    @Test func defaultConfig_sonarr_usesPort8989() {
        let config = ServerConfig.defaultConfig(for: .sonarr)
        #expect(config.url == "http://localhost:8989")
    }

    @Test func defaultConfig_lidarr_usesPort8686() {
        let config = ServerConfig.defaultConfig(for: .lidarr)
        #expect(config.url == "http://localhost:8686")
    }

    @Test func defaultConfig_transmission_usesPort9091() {
        let config = ServerConfig.defaultConfig(for: .transmission)
        #expect(config.url == "http://localhost:9091")
    }

    @Test func defaultConfig_defaultPortMatchesURL() {
        for type in ServerConfig.ServiceType.allCases {
            let config = ServerConfig.defaultConfig(for: type)
            #expect(config.url.contains("\(type.defaultPort)"),
                    "URL for \(type.rawValue) should contain port \(type.defaultPort)")
        }
    }

    // MARK: - baseURL

    @Test func baseURL_validURL_returnsURL() {
        let config = ServerConfig(url: "http://192.168.1.10:7878", apiKey: "abc", isEnabled: true, serviceType: .radarr)
        #expect(config.baseURL == URL(string: "http://192.168.1.10:7878"))
    }

    @Test func baseURL_emptyString_returnsNil() {
        let config = ServerConfig(url: "", apiKey: "", isEnabled: false, serviceType: .radarr)
        #expect(config.baseURL == nil)
    }

    // MARK: - id

    @Test func id_matchesServiceTypeRawValue() {
        for type in ServerConfig.ServiceType.allCases {
            let config = ServerConfig.defaultConfig(for: type)
            #expect(config.id == type.rawValue)
        }
    }
}
