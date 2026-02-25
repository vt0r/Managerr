import SwiftUI

// MARK: - Add Movie Sheet

struct AddMovieSheet: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss

    let movie: RadarrMovie

    @State private var rootFolders: [RadarrRootFolder] = []
    @State private var qualityProfiles: [RadarrQualityProfile] = []
    @State private var selectedRootFolder: Int?
    @State private var selectedQualityProfile: Int?
    @State private var monitored: Bool = true
    @State private var searchOnAdd: Bool = true
    @State private var isLoading: Bool = true
    @State private var isAdding: Bool = false
    @State private var errorMessage: String?
    @State private var didAdd: Bool = false

    private var config: ServerConfig {
        settings.config(for: .radarr)
    }

    var body: some View {
        NavigationStack {
            Form {
                mediaInfoSection

                if isLoading {
                    Section { ProgressView("Loading options...") }
                } else {
                    optionsSection
                    addSection
                }
            }
            .navigationTitle("Add Movie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await loadOptions() }
        }
    }

    private var mediaInfoSection: some View {
        Section {
            HStack(spacing: 12) {
                Color(.secondarySystemBackground)
                    .frame(width: 60, height: 90)
                    .overlay {
                        if let url = movie.posterURL(baseURL: config.baseURL) {
                            CachedAsyncImage(url: url)
                                .allowsHitTesting(false)
                        }
                    }
                    .clipShape(.rect(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 4) {
                    Text(movie.title)
                        .font(.headline)
                    if let year = movie.year {
                        Text(String(year))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let overview = movie.overview {
                        Text(overview)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
            }
        }
    }

    private var optionsSection: some View {
        Section("Options") {
            if !rootFolders.isEmpty {
                Picker("Root Folder", selection: $selectedRootFolder) {
                    ForEach(rootFolders) { folder in
                        Text(folder.path).tag(Optional(folder.id))
                    }
                }
            }

            if !qualityProfiles.isEmpty {
                Picker("Quality Profile", selection: $selectedQualityProfile) {
                    ForEach(qualityProfiles) { profile in
                        Text(profile.name).tag(Optional(profile.id))
                    }
                }
            }

            Toggle("Monitored", isOn: $monitored)
            Toggle("Search on Add", isOn: $searchOnAdd)
        }
    }

    private var addSection: some View {
        Section {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await addMovie() }
            } label: {
                HStack {
                    Spacer()
                    if isAdding {
                        ProgressView()
                    } else if didAdd {
                        Label("Added", systemImage: "checkmark.circle.fill")
                    } else {
                        Text("Add to Radarr")
                    }
                    Spacer()
                }
            }
            .disabled(isAdding || didAdd || selectedRootFolder == nil || selectedQualityProfile == nil)
        }
    }

    private func loadOptions() async {
        do {
            async let folders = ArrService.shared.fetchRadarrRootFolders(config)
            async let profiles = ArrService.shared.fetchRadarrQualityProfiles(config)
            rootFolders = try await folders
            qualityProfiles = try await profiles
            selectedRootFolder = rootFolders.first?.id
            selectedQualityProfile = qualityProfiles.first?.id
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func addMovie() async {
        guard let rootFolder = rootFolders.first(where: { $0.id == selectedRootFolder }),
              let qualityProfileId = selectedQualityProfile else { return }

        isAdding = true
        errorMessage = nil

        do {
            var dict: [String: Any] = [
                "title": movie.title,
                "qualityProfileId": qualityProfileId,
                "rootFolderPath": rootFolder.path,
                "monitored": monitored,
                "addOptions": ["searchForMovie": searchOnAdd]
            ]
            if let tmdbId = movie.tmdbId { dict["tmdbId"] = tmdbId }
            if let year = movie.year { dict["year"] = year }
            if let images = movie.images {
                dict["images"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(images))
            }

            let body = try JSONSerialization.data(withJSONObject: dict)
            try await ArrService.shared.addRadarrMovie(config, movie: body)
            didAdd = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isAdding = false
    }
}

// MARK: - Add Series Sheet

struct AddSeriesSheet: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss

    let series: SonarrSeries

    @State private var rootFolders: [SonarrRootFolder] = []
    @State private var qualityProfiles: [SonarrQualityProfile] = []
    @State private var selectedRootFolder: Int?
    @State private var selectedQualityProfile: Int?
    @State private var monitored: Bool = true
    @State private var searchOnAdd: Bool = true
    @State private var isLoading: Bool = true
    @State private var isAdding: Bool = false
    @State private var errorMessage: String?
    @State private var didAdd: Bool = false

    private var config: ServerConfig {
        settings.config(for: .sonarr)
    }

    var body: some View {
        NavigationStack {
            Form {
                mediaInfoSection

                if isLoading {
                    Section { ProgressView("Loading options...") }
                } else {
                    optionsSection
                    addSection
                }
            }
            .navigationTitle("Add Series")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await loadOptions() }
        }
    }

    private var mediaInfoSection: some View {
        Section {
            HStack(spacing: 12) {
                Color(.secondarySystemBackground)
                    .frame(width: 60, height: 90)
                    .overlay {
                        if let url = series.posterURL(baseURL: config.baseURL) {
                            CachedAsyncImage(url: url)
                                .allowsHitTesting(false)
                        }
                    }
                    .clipShape(.rect(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 4) {
                    Text(series.title)
                        .font(.headline)
                    HStack(spacing: 8) {
                        if let year = series.year { Text(String(year)) }
                        if let network = series.network { Text(network) }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    if let overview = series.overview {
                        Text(overview)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
            }
        }
    }

    private var optionsSection: some View {
        Section("Options") {
            if !rootFolders.isEmpty {
                Picker("Root Folder", selection: $selectedRootFolder) {
                    ForEach(rootFolders) { folder in
                        Text(folder.path).tag(Optional(folder.id))
                    }
                }
            }

            if !qualityProfiles.isEmpty {
                Picker("Quality Profile", selection: $selectedQualityProfile) {
                    ForEach(qualityProfiles) { profile in
                        Text(profile.name).tag(Optional(profile.id))
                    }
                }
            }

            Toggle("Monitored", isOn: $monitored)
            Toggle("Search on Add", isOn: $searchOnAdd)
        }
    }

    private var addSection: some View {
        Section {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await addSeries() }
            } label: {
                HStack {
                    Spacer()
                    if isAdding {
                        ProgressView()
                    } else if didAdd {
                        Label("Added", systemImage: "checkmark.circle.fill")
                    } else {
                        Text("Add to Sonarr")
                    }
                    Spacer()
                }
            }
            .disabled(isAdding || didAdd || selectedRootFolder == nil || selectedQualityProfile == nil)
        }
    }

    private func loadOptions() async {
        do {
            async let folders = ArrService.shared.fetchSonarrRootFolders(config)
            async let profiles = ArrService.shared.fetchSonarrQualityProfiles(config)
            rootFolders = try await folders
            qualityProfiles = try await profiles
            selectedRootFolder = rootFolders.first?.id
            selectedQualityProfile = qualityProfiles.first?.id
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func addSeries() async {
        guard let rootFolder = rootFolders.first(where: { $0.id == selectedRootFolder }),
              let qualityProfileId = selectedQualityProfile else { return }

        isAdding = true
        errorMessage = nil

        do {
            var dict: [String: Any] = [
                "title": series.title,
                "qualityProfileId": qualityProfileId,
                "rootFolderPath": rootFolder.path,
                "monitored": monitored,
                "addOptions": [
                    "searchForMissingEpisodes": searchOnAdd,
                    "searchForCutoffUnmetEpisodes": false
                ]
            ]
            if let tvdbId = series.tvdbId { dict["tvdbId"] = tvdbId }
            if let year = series.year { dict["year"] = year }
            if let seriesType = series.seriesType { dict["seriesType"] = seriesType }
            if let seasons = series.seasons {
                dict["seasons"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(seasons))
            }
            if let images = series.images {
                dict["images"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(images))
            }

            let body = try JSONSerialization.data(withJSONObject: dict)
            try await ArrService.shared.addSonarrSeries(config, series: body)
            didAdd = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isAdding = false
    }
}

// MARK: - Add Artist Sheet

struct AddArtistSheet: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss

    let artist: LidarrArtist

    @State private var rootFolders: [LidarrRootFolder] = []
    @State private var qualityProfiles: [LidarrQualityProfile] = []
    @State private var metadataProfiles: [LidarrMetadataProfile] = []
    @State private var selectedRootFolder: Int?
    @State private var selectedQualityProfile: Int?
    @State private var selectedMetadataProfile: Int?
    @State private var monitored: Bool = true
    @State private var searchOnAdd: Bool = true
    @State private var isLoading: Bool = true
    @State private var isAdding: Bool = false
    @State private var errorMessage: String?
    @State private var didAdd: Bool = false

    private var config: ServerConfig {
        settings.config(for: .lidarr)
    }

    var body: some View {
        NavigationStack {
            Form {
                mediaInfoSection

                if isLoading {
                    Section { ProgressView("Loading options...") }
                } else {
                    optionsSection
                    addSection
                }
            }
            .navigationTitle("Add Artist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await loadOptions() }
        }
    }

    private var mediaInfoSection: some View {
        Section {
            HStack(spacing: 12) {
                Color(.secondarySystemBackground)
                    .frame(width: 60, height: 60)
                    .overlay {
                        if let url = artist.posterURL(config: config) {
                            CachedAsyncImage(url: url)
                                .allowsHitTesting(false)
                        }
                    }
                    .clipShape(.rect(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 4) {
                    Text(artist.artistName ?? "Unknown")
                        .font(.headline)
                    if let overview = artist.overview {
                        Text(overview)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
            }
        }
    }

    private var optionsSection: some View {
        Section("Options") {
            if !rootFolders.isEmpty {
                Picker("Root Folder", selection: $selectedRootFolder) {
                    ForEach(rootFolders) { folder in
                        Text(folder.path).tag(Optional(folder.id))
                    }
                }
            }

            if !qualityProfiles.isEmpty {
                Picker("Quality Profile", selection: $selectedQualityProfile) {
                    ForEach(qualityProfiles) { profile in
                        Text(profile.name).tag(Optional(profile.id))
                    }
                }
            }

            if !metadataProfiles.isEmpty {
                Picker("Metadata Profile", selection: $selectedMetadataProfile) {
                    ForEach(metadataProfiles) { profile in
                        Text(profile.name).tag(Optional(profile.id))
                    }
                }
            }

            Toggle("Monitored", isOn: $monitored)
            Toggle("Search on Add", isOn: $searchOnAdd)
        }
    }

    private var addSection: some View {
        Section {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await addArtist() }
            } label: {
                HStack {
                    Spacer()
                    if isAdding {
                        ProgressView()
                    } else if didAdd {
                        Label("Added", systemImage: "checkmark.circle.fill")
                    } else {
                        Text("Add to Lidarr")
                    }
                    Spacer()
                }
            }
            .disabled(isAdding || didAdd || selectedRootFolder == nil || selectedQualityProfile == nil || selectedMetadataProfile == nil)
        }
    }

    private func loadOptions() async {
        do {
            async let folders = ArrService.shared.fetchLidarrRootFolders(config)
            async let profiles = ArrService.shared.fetchLidarrQualityProfiles(config)
            async let metadata = ArrService.shared.fetchLidarrMetadataProfiles(config)
            rootFolders = try await folders
            qualityProfiles = try await profiles
            metadataProfiles = try await metadata
            selectedRootFolder = rootFolders.first?.id
            selectedQualityProfile = qualityProfiles.first?.id
            selectedMetadataProfile = metadataProfiles.first?.id
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func addArtist() async {
        guard let rootFolder = rootFolders.first(where: { $0.id == selectedRootFolder }),
              let qualityProfileId = selectedQualityProfile,
              let metadataProfileId = selectedMetadataProfile else { return }

        isAdding = true
        errorMessage = nil

        do {
            var dict: [String: Any] = [
                "artistName": artist.artistName ?? "Unknown",
                "qualityProfileId": qualityProfileId,
                "metadataProfileId": metadataProfileId,
                "rootFolderPath": rootFolder.path,
                "monitored": monitored,
                "addOptions": ["searchForMissingAlbums": searchOnAdd]
            ]
            if let foreignArtistId = artist.foreignArtistId {
                dict["foreignArtistId"] = foreignArtistId
            }
            if let images = artist.images {
                dict["images"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(images))
            }

            let body = try JSONSerialization.data(withJSONObject: dict)
            try await ArrService.shared.addLidarrArtist(config, artist: body)
            didAdd = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isAdding = false
    }
}
