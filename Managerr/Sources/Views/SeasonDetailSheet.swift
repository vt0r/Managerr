import SwiftUI

struct SeasonDetailSheet: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss
    let season: SonarrSeason
    let series: SonarrSeries
    let episodes: [SonarrEpisode]
    let viewModel: SonarrViewModel

    @State private var showAutoSeasonSearchConfirm: Bool = false
    @State private var showManualSeasonSearch: Bool = false
    @State private var searchingEpisode: SonarrEpisode?
    @State private var manualSearchEpisode: SonarrEpisode?
    @State private var showDeleteSeasonConfirm: Bool = false
    @State private var deletingEpisode: SonarrEpisode?
    @State private var deletedEpisodeFileIds: Set<Int> = []

    private var sonarrConfig: ServerConfig { settings.config(for: .sonarr) }
    private var seasonTitle: String {
        season.seasonNumber == 0 ? "Specials" : "Season \(season.seasonNumber)"
    }
    private var sortedEpisodes: [SonarrEpisode] {
        episodes.sorted { $0.episodeNumber < $1.episodeNumber }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Button {
                            showAutoSeasonSearchConfirm = true
                        } label: {
                            Label("Auto Search", systemImage: "magnifyingglass")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            showManualSeasonSearch = true
                        } label: {
                            Label("Manual Search", systemImage: "list.bullet.rectangle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    Text("Episodes")
                        .font(.headline)

                    if sortedEpisodes.isEmpty {
                        ContentUnavailableView(
                            "No Episodes",
                            systemImage: "tv",
                            description: Text("No episode data available.")
                        )
                    } else {
                        VStack(spacing: 0) {
                            ForEach(sortedEpisodes) { episode in
                                episodeRow(episode)
                                if episode.id != sortedEpisodes.last?.id {
                                    Divider()
                                        .padding(.leading, 52)
                                }
                            }
                        }
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding()
            }
            .navigationTitle(seasonTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Menu {
                            Button(role: .destructive) {
                                showDeleteSeasonConfirm = true
                            } label: {
                                Label("Delete Season Files", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }

                        Button("Done") { dismiss() }
                    }
                }
            }
            .alert("Search \(seasonTitle)?", isPresented: $showAutoSeasonSearchConfirm) {
                Button("Search") {
                    Task {
                        await viewModel.searchSeason(sonarrConfig, seriesId: series.id, seasonNumber: season.seasonNumber)
                        await viewModel.fetchSeriesSilently(sonarrConfig)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Sonarr will search all configured indexers for \(seasonTitle) of \(series.title).")
            }
            .alert("Delete Season Files?", isPresented: $showDeleteSeasonConfirm) {
                Button("Delete", role: .destructive) {
                    let fileIds = sortedEpisodes.compactMap { ep -> Int? in
                        guard ep.hasFile, let fid = ep.episodeFileId, !deletedEpisodeFileIds.contains(fid) else { return nil }
                        return fid
                    }
                    Task {
                        await viewModel.deleteSeasonFiles(sonarrConfig, episodeFileIds: fileIds)
                        fileIds.forEach { deletedEpisodeFileIds.insert($0) }
                        await viewModel.fetchSeriesSilently(sonarrConfig)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Delete all downloaded files for \(seasonTitle) of \(series.title)? This cannot be undone.")
            }
            .alert(
                "Delete Episode File?",
                isPresented: Binding(get: { deletingEpisode != nil }, set: { if !$0 { deletingEpisode = nil } }),
                presenting: deletingEpisode
            ) { episode in
                Button("Delete", role: .destructive) {
                    guard let fileId = episode.episodeFileId else { deletingEpisode = nil; return }
                    Task {
                        await viewModel.deleteEpisodeFile(sonarrConfig, episodeFileId: fileId)
                        deletedEpisodeFileIds.insert(fileId)
                        await viewModel.fetchSeriesSilently(sonarrConfig)
                    }
                    deletingEpisode = nil
                }
                Button("Cancel", role: .cancel) { deletingEpisode = nil }
            } message: { episode in
                Text("Delete the file for \"\(episode.title ?? "this episode")\"? This cannot be undone.")
            }
            .sheet(isPresented: $showManualSeasonSearch) {
                ManualSearchView(
                    title: "\(series.title) – \(seasonTitle)",
                    fetchReleases: {
                        try await ArrService.shared.fetchSonarrReleases(sonarrConfig, seriesId: series.id, seasonNumber: season.seasonNumber)
                    },
                    grabRelease: { release in
                        try await ArrService.shared.grabSonarrRelease(sonarrConfig, guid: release.guid, indexerId: release.indexerId)
                    }
                )
            }
            .confirmationDialog(
                searchingEpisode.map { "S\($0.seasonNumber)E\($0.episodeNumber): \($0.title ?? "Episode")" } ?? "",
                isPresented: Binding(get: { searchingEpisode != nil }, set: { if !$0 { searchingEpisode = nil } }),
                titleVisibility: .visible
            ) {
                Button("Auto Search") {
                    guard let ep = searchingEpisode else { return }
                    searchingEpisode = nil
                    Task {
                        await viewModel.searchEpisode(sonarrConfig, episodeId: ep.id)
                        await viewModel.fetchSeriesSilently(sonarrConfig)
                    }
                }
                Button("Manual Search") {
                    manualSearchEpisode = searchingEpisode
                    searchingEpisode = nil
                }
                Button("Cancel", role: .cancel) { searchingEpisode = nil }
            }
            .sheet(item: $manualSearchEpisode) { ep in
                ManualSearchView(
                    title: "S\(ep.seasonNumber)E\(ep.episodeNumber): \(ep.title ?? "Episode")",
                    fetchReleases: {
                        try await ArrService.shared.fetchSonarrEpisodeReleases(sonarrConfig, episodeId: ep.id)
                    },
                    grabRelease: { release in
                        try await ArrService.shared.grabSonarrRelease(sonarrConfig, guid: release.guid, indexerId: release.indexerId)
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func episodeRow(_ episode: SonarrEpisode) -> some View {
        let isImported = episode.hasFile && episode.episodeFileId != nil && !(episode.episodeFileId.map { deletedEpisodeFileIds.contains($0) } ?? false)
        let isDownloading = episode.hasFile && episode.episodeFileId == nil
        HStack(spacing: 8) {
            Text("S\(episode.seasonNumber)E\(episode.episodeNumber)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(episode.title ?? "TBA")
                    .font(.subheadline)
                    .lineLimit(1)
                if let airDate = episode.airDate, !airDate.isEmpty {
                    Text(airDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: isImported ? "checkmark.circle.fill" : isDownloading ? "arrow.down.circle.fill" : "circle")
                .foregroundStyle(isImported ? Color.green : isDownloading ? Color.orange : Color(.tertiaryLabel))

            Button {
                searchingEpisode = episode
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.body)
                    .padding(8)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .contextMenu {
            if isImported {
                Button(role: .destructive) {
                    deletingEpisode = episode
                } label: {
                    Label("Delete File", systemImage: "trash")
                }
            }
        }
    }
}
