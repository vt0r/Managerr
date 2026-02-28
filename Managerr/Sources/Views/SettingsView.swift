import SwiftUI

struct SettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @State private var editingConfig: ServerConfig?

    private var defaultTabOptions: [TabSelection] {
        [.movies, .tvShows, .music, .downloads]
    }

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            List {
                Section {
                    Picker("Default View", selection: $settings.defaultTab) {
                        ForEach(defaultTabOptions, id: \.self) { tab in
                            Text(tab.displayName).tag(tab)
                        }
                    }
                } header: {
                    Text("General")
                } footer: {
                    Text("Choose which service appears when the app opens.")
                }

                Section("Services") {
                    ForEach(ServerConfig.ServiceType.allCases, id: \.self) { type in
                        let config = settings.config(for: type)
                        Button {
                            editingConfig = config
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: type.icon)
                                    .font(.title3)
                                    .foregroundStyle(config.isEnabled ? .primary : .tertiary)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(type.displayName)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Text(config.isEnabled ? config.url : "Not configured")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Circle()
                                    .fill(config.isEnabled ? Color.green : Color(.tertiaryLabel))
                                    .frame(width: 8, height: 8)

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .tint(.primary)
                    }
                }

                Section {
                    Link(destination: URL(string: "https://wiki.servarr.com")!) {
                        Label("Servarr Wiki", systemImage: "book")
                    }
                    Link(destination: URL(string: "https://github.com/transmission/transmission")!) {
                        Label("Transmission Docs", systemImage: "doc.text")
                    }
                } header: {
                    Text("Resources")
                }
            }
            .navigationTitle("Settings")
            .onChange(of: settings.defaultTab) { _, _ in
                settings.save()
            }
            .sheet(item: $editingConfig) { config in
                ServiceConfigSheet(config: config)
            }
        }
    }
}

extension TabSelection {
    var displayName: String {
        switch self {
        case .movies: "Movies"
        case .tvShows: "TV Shows"
        case .music: "Music"
        case .downloads: "Downloads"
        case .search: "Search"
        case .settings: "Settings"
        }
    }
}

struct ServiceConfigSheet: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss
    let config: ServerConfig

    @State private var url: String
    @State private var apiKey: String
    @State private var isEnabled: Bool
    @State private var showPeerFlags: Bool
    @State private var isTesting: Bool = false
    @State private var testResult: String?

    init(config: ServerConfig) {
        self.config = config
        _url = State(initialValue: config.url)
        _apiKey = State(initialValue: config.apiKey)
        _isEnabled = State(initialValue: config.isEnabled)
        _showPeerFlags = State(initialValue: UserDefaults.standard.object(forKey: "showPeerFlags") as? Bool ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Enabled", isOn: $isEnabled)
                }

                Section("Connection") {
                    TextField("Server URL", text: $url, prompt: Text(config.serviceType.defaultURLHint))
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    SecureField(config.serviceType.credType, text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Section {
                    Button {
                        Task { await testConnection() }
                    } label: {
                        HStack {
                            Text("Test Connection")
                            Spacer()
                            if isTesting {
                                ProgressView()
                            } else if let testResult {
                                Image(systemName: testResult == "OK" ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(testResult == "OK" ? .green : .red)
                            }
                        }
                    }
                    .disabled(url.isEmpty || isTesting)

                    if let testResult, testResult != "OK" {
                        Text(testResult)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                if config.serviceType == .transmission {
                    Section {
                        Toggle("Show Peer Country Flags", isOn: $showPeerFlags)
                    } footer: {
                        Text("Looks up the country for each torrent peer IP using the free [`country.is`](https://country.is/) service, then shows a flag. Requires an internet connection.")
                    }
                }

                Section {
                    Text("**Server URL:** Enter the full URL where \(config.serviceType.displayName) is reachable, starting with the protocol string (**http://** or **https://**), followed by the IP or hostname, and ending with a colon (**:**) plus the port number. The default port for \(config.serviceType.displayName) is **\(config.serviceType.defaultPort, format: .number.grouping(.never))**.\n\n**\(config.serviceType.credType):** \(config.serviceType.credSummary)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Help")
                }
            }
            .navigationTitle(config.serviceType.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = config
                        updated.url = url
                        updated.apiKey = apiKey
                        updated.isEnabled = isEnabled
                        settings.updateConfig(updated)
                        settings.showPeerFlags = showPeerFlags
                        settings.save()
                        dismiss()
                    }
                }
            }
        }
    }

    private func testConnection() async {
        isTesting = true
        testResult = nil

        do {
            var testConfig = config
            testConfig.url = url
            testConfig.apiKey = apiKey

            switch config.serviceType {
            case .radarr:
                let url = URL(string: "\(url)/api/v3/system/status")!
                let _: [String: AnyCodable] = try await NetworkService.shared.request(
                    url: url,
                    headers: ["X-Api-Key": apiKey]
                )
                testResult = "OK"
            case .sonarr:
                let url = URL(string: "\(url)/api/v3/system/status")!
                let _: [String: AnyCodable] = try await NetworkService.shared.request(
                    url: url,
                    headers: ["X-Api-Key": apiKey]
                )
                testResult = "OK"
            case .lidarr:
                let url = URL(string: "\(url)/api/v1/system/status")!
                let _: [String: AnyCodable] = try await NetworkService.shared.request(
                    url: url,
                    headers: ["X-Api-Key": apiKey]
                )
                testResult = "OK"
            case .transmission:
                _ = try await TransmissionService.shared.fetchTorrents(testConfig)
                testResult = "OK"
            }
        } catch {
            testResult = error.localizedDescription
        }

        isTesting = false
    }
}
