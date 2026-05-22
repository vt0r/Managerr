import SwiftUI

struct ArtistEditSheet: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss

    let artist: LidarrArtist
    let onSaved: () -> Void

    @State private var qualityProfileId: Int
    @State private var metadataProfileId: Int
    @State private var monitored: Bool
    @State private var rootFolderPath: String
    @State private var selectedTagIds: Set<Int>
    @State private var monitorNewItems: String

    @State private var qualityProfiles: [LidarrQualityProfile] = []
    @State private var metadataProfiles: [LidarrMetadataProfile] = []
    @State private var rootFolders: [LidarrRootFolder] = []
    @State private var availableTags: [ArrTag] = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let monitorNewItemsOptions: [(String, String)] = [
        ("all", "All Albums"),
        ("new", "New Albums"),
        ("none", "No New Albums"),
    ]

    init(artist: LidarrArtist, onSaved: @escaping () -> Void) {
        self.artist = artist
        self.onSaved = onSaved
        _qualityProfileId = State(initialValue: artist.qualityProfileId ?? 0)
        _metadataProfileId = State(initialValue: artist.metadataProfileId ?? 0)
        _monitored = State(initialValue: artist.monitored)
        _rootFolderPath = State(initialValue: artist.rootFolderPath ?? "")
        _selectedTagIds = State(initialValue: Set(artist.tags ?? []))
        _monitorNewItems = State(initialValue: artist.monitorNewItems ?? "all")
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading...")
                } else if let error = errorMessage {
                    ContentUnavailableView {
                        Label("Error", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    }
                } else {
                    form
                }
            }
            .navigationTitle("Edit Artist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isSaving {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Button("Save") { Task { await save() } }
                            .disabled(isLoading)
                    }
                }
            }
        }
        .task { await loadData() }
    }

    private var form: some View {
        Form {
            Section("Monitoring") {
                Toggle("Monitored", isOn: $monitored)
                Picker("Monitor New Albums", selection: $monitorNewItems) {
                    ForEach(monitorNewItemsOptions, id: \.0) { value, label in
                        Text(label).tag(value)
                    }
                }
            }

            Section("Profiles") {
                if !qualityProfiles.isEmpty {
                    Picker("Quality Profile", selection: $qualityProfileId) {
                        ForEach(qualityProfiles) { profile in
                            Text(profile.name).tag(profile.id)
                        }
                    }
                }
                if !metadataProfiles.isEmpty {
                    Picker("Metadata Profile", selection: $metadataProfileId) {
                        ForEach(metadataProfiles) { profile in
                            Text(profile.name).tag(profile.id)
                        }
                    }
                }
            }

            if !rootFolders.isEmpty {
                Section("Storage") {
                    Picker("Root Folder", selection: $rootFolderPath) {
                        ForEach(rootFolders) { folder in
                            Text(folder.path).tag(folder.path)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
            }

            Section("Tags") {
                if availableTags.isEmpty {
                    Text("No tags configured in Lidarr")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(availableTags) { tag in
                        Toggle(tag.label, isOn: Binding(
                            get: { selectedTagIds.contains(tag.id) },
                            set: { if $0 { selectedTagIds.insert(tag.id) } else { selectedTagIds.remove(tag.id) } }
                        ))
                    }
                }
            }
        }
    }

    private func loadData() async {
        isLoading = true
        let config = settings.config(for: .lidarr)
        qualityProfiles = (try? await ArrService.shared.fetchLidarrQualityProfiles(config)) ?? []
        metadataProfiles = (try? await ArrService.shared.fetchLidarrMetadataProfiles(config)) ?? []
        rootFolders = (try? await ArrService.shared.fetchLidarrRootFolders(config)) ?? []
        availableTags = (try? await ArrService.shared.fetchLidarrTags(config)) ?? []
        isLoading = false
    }

    private func save() async {
        isSaving = true
        do {
            try await ArrService.shared.updateLidarrArtist(
                settings.config(for: .lidarr),
                artist: artist,
                qualityProfileId: qualityProfileId,
                metadataProfileId: metadataProfileId,
                monitored: monitored,
                rootFolderPath: rootFolderPath,
                tags: Array(selectedTagIds),
                monitorNewItems: monitorNewItems
            )
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
}
