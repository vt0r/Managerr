import SwiftUI

struct SeriesEditSheet: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss

    let series: SonarrSeries
    let onSaved: () -> Void

    @State private var qualityProfileId: Int
    @State private var monitored: Bool
    @State private var seriesType: String
    @State private var rootFolderPath: String
    @State private var selectedTagIds: Set<Int>
    @State private var monitorNewItems: String
    @State private var seasonFolder: Bool

    @State private var qualityProfiles: [SonarrQualityProfile] = []
    @State private var rootFolders: [SonarrRootFolder] = []
    @State private var availableTags: [ArrTag] = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let seriesTypeOptions: [(String, String)] = [
        ("standard", "Standard"),
        ("daily", "Daily"),
        ("anime", "Anime"),
    ]

    private let monitorNewItemsOptions: [(String, String)] = [
        ("all", "All New Seasons"),
        ("none", "No New Seasons"),
    ]

    init(series: SonarrSeries, onSaved: @escaping () -> Void) {
        self.series = series
        self.onSaved = onSaved
        _qualityProfileId = State(initialValue: series.qualityProfileId ?? 0)
        _monitored = State(initialValue: series.monitored)
        _seriesType = State(initialValue: series.seriesType ?? "standard")
        _rootFolderPath = State(initialValue: series.rootFolderPath ?? "")
        _selectedTagIds = State(initialValue: Set(series.tags ?? []))
        _monitorNewItems = State(initialValue: series.monitorNewItems ?? "all")
        _seasonFolder = State(initialValue: series.seasonFolder ?? true)
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
            .navigationTitle("Edit Series")
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
                Picker("Monitor New Seasons", selection: $monitorNewItems) {
                    ForEach(monitorNewItemsOptions, id: \.0) { value, label in
                        Text(label).tag(value)
                    }
                }
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

            Section("Series") {
                Picker("Series Type", selection: $seriesType) {
                    ForEach(seriesTypeOptions, id: \.0) { value, label in
                        Text(label).tag(value)
                    }
                }
                Toggle("Use Season Folders", isOn: $seasonFolder)
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
                    Text("No tags configured in Sonarr")
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
        let config = settings.config(for: .sonarr)
        qualityProfiles = (try? await ArrService.shared.fetchSonarrQualityProfiles(config)) ?? []
        rootFolders = (try? await ArrService.shared.fetchSonarrRootFolders(config)) ?? []
        availableTags = (try? await ArrService.shared.fetchSonarrTags(config)) ?? []
        isLoading = false
    }

    private func save() async {
        isSaving = true
        do {
            try await ArrService.shared.updateSonarrSeries(
                settings.config(for: .sonarr),
                series: series,
                qualityProfileId: qualityProfileId,
                monitored: monitored,
                seriesType: seriesType,
                rootFolderPath: rootFolderPath,
                tags: Array(selectedTagIds),
                monitorNewItems: monitorNewItems,
                seasonFolder: seasonFolder
            )
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
}
