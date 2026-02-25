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
                    }
                }
                .padding()
            }
            .navigationTitle(seasonTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Search \(seasonTitle)?", isPresented: $showAutoSeasonSearchConfirm) {
                Button("Search") {
                    Task { await viewModel.searchSeason(sonarrConfig, seriesId: series.id, seasonNumber: season.seasonNumber) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Sonarr will search all configured indexers for \(seasonTitle) of \(series.title).")
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
                    Task { await viewModel.searchEpisode(sonarrConfig, episodeId: ep.id) }
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

            Image(systemName: episode.hasFile ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(episode.hasFile ? Color.green : Color(.tertiaryLabel))

            Button {
                searchingEpisode = episode
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.body)
                    .padding(8)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 12)
    }
}
