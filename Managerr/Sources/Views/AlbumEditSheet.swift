import SwiftUI

struct AlbumEditSheet: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss

    let album: LidarrAlbum
    let onSaved: () -> Void

    @State private var monitored: Bool
    @State private var anyReleaseOk: Bool
    @State private var selectedReleaseId: Int?

    @State private var albumDetail: LidarrAlbum?
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(album: LidarrAlbum, onSaved: @escaping () -> Void) {
        self.album = album
        self.onSaved = onSaved
        _monitored = State(initialValue: album.monitored)
        _anyReleaseOk = State(initialValue: album.anyReleaseOk ?? true)
        _selectedReleaseId = State(initialValue: album.releases?.first(where: { $0.monitored })?.id)
    }

    private var releases: [LidarrAlbumRelease] {
        (albumDetail ?? album).releases ?? []
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
            .navigationTitle("Edit Album")
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

            Section("Release") {
                Toggle(isOn: $anyReleaseOk) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Automatically Switch Release")
                        Text("Lidarr will automatically switch to the release best matching downloaded tracks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !releases.isEmpty {
                    Picker("Release", selection: $selectedReleaseId) {
                        ForEach(releases) { release in
                            Text(releaseLabel(release)).tag(Optional(release.id))
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .disabled(anyReleaseOk)
                }
            }
        }
    }

    private func releaseLabel(_ release: LidarrAlbumRelease) -> String {
        var parts: [String] = []
        if let title = release.title, !title.isEmpty { parts.append(title) }
        if let count = release.trackCount { parts.append("\(count) tracks") }
        if let status = release.status, !status.isEmpty { parts.append(status) }
        return parts.joined(separator: " · ")
    }

    private func loadData() async {
        isLoading = true
        let config = settings.config(for: .lidarr)
        if let detail = try? await ArrService.shared.fetchLidarrAlbumDetail(config, albumId: album.id) {
            albumDetail = detail
            if selectedReleaseId == nil {
                selectedReleaseId = detail.releases?.first(where: { $0.monitored })?.id
            }
        }
        isLoading = false
    }

    private func save() async {
        isSaving = true
        do {
            try await ArrService.shared.updateLidarrAlbum(
                settings.config(for: .lidarr),
                album: albumDetail ?? album,
                monitored: monitored,
                anyReleaseOk: anyReleaseOk,
                selectedReleaseId: anyReleaseOk ? nil : selectedReleaseId
            )
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
}
