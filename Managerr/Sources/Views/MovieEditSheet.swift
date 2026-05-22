import SwiftUI

struct MovieEditSheet: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss

    let movie: RadarrMovie
    let onSaved: () -> Void

    @State private var qualityProfileId: Int
    @State private var monitored: Bool
    @State private var minimumAvailability: String
    @State private var rootFolderPath: String
    @State private var selectedTagIds: Set<Int>

    @State private var qualityProfiles: [RadarrQualityProfile] = []
    @State private var rootFolders: [RadarrRootFolder] = []
    @State private var availableTags: [ArrTag] = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let availabilityOptions: [(String, String)] = [
        ("tba", "TBA"),
        ("announced", "Announced"),
        ("inCinemas", "In Cinemas"),
        ("released", "Released"),
        ("preDB", "PreDB"),
    ]

    init(movie: RadarrMovie, onSaved: @escaping () -> Void) {
        self.movie = movie
        self.onSaved = onSaved
        _qualityProfileId = State(initialValue: movie.qualityProfileId ?? 0)
        _monitored = State(initialValue: movie.monitored)
        _minimumAvailability = State(initialValue: movie.minimumAvailability ?? "announced")
        _rootFolderPath = State(initialValue: movie.rootFolderPath ?? "")
        _selectedTagIds = State(initialValue: Set(movie.tags ?? []))
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
            .navigationTitle("Edit Movie")
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
            }

            if !qualityProfiles.isEmpty {
                Section("Quality") {
                    Picker("Quality Profile", selection: $qualityProfileId) {
                        ForEach(qualityProfiles) { profile in
                            Text(profile.name).tag(profile.id)
                        }
                    }
                }
            }

            Section("Availability") {
                Picker("Minimum Availability", selection: $minimumAvailability) {
                    ForEach(availabilityOptions, id: \.0) { value, label in
                        Text(label).tag(value)
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
                    Text("No tags configured in Radarr")
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
        let config = settings.config(for: .radarr)
        qualityProfiles = (try? await ArrService.shared.fetchRadarrQualityProfiles(config)) ?? []
        rootFolders = (try? await ArrService.shared.fetchRadarrRootFolders(config)) ?? []
        availableTags = (try? await ArrService.shared.fetchRadarrTags(config)) ?? []
        isLoading = false
    }

    private func save() async {
        isSaving = true
        do {
            try await ArrService.shared.updateRadarrMovie(
                settings.config(for: .radarr),
                movie: movie,
                qualityProfileId: qualityProfileId,
                monitored: monitored,
                minimumAvailability: minimumAvailability,
                rootFolderPath: rootFolderPath,
                tags: Array(selectedTagIds)
            )
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
}
