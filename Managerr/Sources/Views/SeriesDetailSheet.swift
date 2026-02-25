import SwiftUI

struct SeriesDetailSheet: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss
    let series: SonarrSeries
    let viewModel: SonarrViewModel

    @State private var showDeleteConfirmation: Bool = false
    @State private var localMonitored: Bool
    @State private var showManualSearch: Bool = false
    @State private var episodes: [SonarrEpisode] = []
    @State private var isLoadingEpisodes: Bool = false
    @State private var selectedSeason: SonarrSeason?

    init(series: SonarrSeries, viewModel: SonarrViewModel) {
        self.series = series
        self.viewModel = viewModel
        _localMonitored = State(initialValue: series.monitored)
    }

    private var baseURL: URL? {
        settings.config(for: .sonarr).baseURL
    }

    private func loadEpisodes() async {
        guard episodes.isEmpty else { return }
        isLoadingEpisodes = true
        if let fetched = try? await ArrService.shared.fetchSonarrEpisodes(
            settings.config(for: .sonarr), seriesId: series.id) {
            episodes = fetched
        }
        isLoadingEpisodes = false
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    detailsSection
                }
            }
            .navigationTitle(series.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            localMonitored.toggle()
                            Task {
                                let ok = await viewModel.toggleMonitored(settings.config(for: .sonarr), show: series)
                                if !ok { localMonitored.toggle() }
                            }
                        } label: {
                            Image(systemName: localMonitored ? "eye.fill" : "eye.slash")
                        }

                        Button("Done") { dismiss() }
                    }
                }
            }
            .task { await loadEpisodes() }
            .sheet(item: $selectedSeason) { season in
                SeasonDetailSheet(
                    season: season,
                    series: series,
                    episodes: episodes.filter { $0.seasonNumber == season.seasonNumber },
                    viewModel: viewModel
                )
            }
            .confirmationDialog("Delete Series", isPresented: $showDeleteConfirmation) {
                Button("Delete from Sonarr", role: .destructive) {
                    Task {
                        await viewModel.deleteSeries(settings.config(for: .sonarr), show: series, deleteFiles: false)
                        dismiss()
                    }
                }
                Button("Delete with Files", role: .destructive) {
                    Task {
                        await viewModel.deleteSeries(settings.config(for: .sonarr), show: series, deleteFiles: true)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var headerSection: some View {
        Color(.secondarySystemBackground)
            .frame(height: 200)
            .overlay {
                if let url = series.fanartURL(baseURL: baseURL) {
                    CachedAsyncImage(url: url)
                        .allowsHitTesting(false)
                }
            }
            .clipShape(.rect(cornerRadius: 0))
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [.clear, Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 80)
            }
            .overlay(alignment: .bottomLeading) {
                HStack(alignment: .bottom, spacing: 12) {
                    Color(.tertiarySystemBackground)
                        .frame(width: 80, height: 120)
                        .overlay {
                            if let url = series.posterURL(baseURL: baseURL) {
                                CachedAsyncImage(url: url)
                                    .allowsHitTesting(false)
                            }
                        }
                        .clipShape(.rect(cornerRadius: 8))
                        .shadow(radius: 4)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(series.title)
                            .font(.title3.bold())
                            .lineLimit(2)

                        HStack(spacing: 8) {
                            if let year = series.year { Text(String(year)) }
                            if let network = series.network { Text(network) }
                            if let status = series.status?.capitalized { Text(status) }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let stats = series.statistics {
                HStack(spacing: 24) {
                    statBadge(value: "\(stats.seasonCount ?? 0)", label: "Seasons")
                    statBadge(value: "\(stats.episodeFileCount ?? 0)/\(stats.episodeCount ?? 0)", label: "Episodes")
                    if let size = stats.sizeOnDisk, size > 0 {
                        statBadge(value: FormatUtils.fileSize(size), label: "Size")
                    }
                }
            }

            if let ratings = series.ratings, let value = ratings.value, value > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text(String(format: "%.1f", value))
                        .font(.headline)
                    if let votes = ratings.votes {
                        Text("(\(votes) votes)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let overview = series.overview, !overview.isEmpty {
                Text(overview)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            if let genres = series.genres, !genres.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(genres, id: \.self) { genre in
                            Text(genre)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color(.tertiarySystemBackground), in: Capsule())
                        }
                    }
                }
                .contentMargins(.horizontal, 16)
            }

            if let seasons = series.seasons, !seasons.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Seasons")
                            .font(.headline)
                        if isLoadingEpisodes {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }

                    ForEach(seasons) { season in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(season.monitored ? Color.accentColor : Color(.tertiaryLabel))
                                .frame(width: 6, height: 6)

                            Text(season.seasonNumber == 0 ? "Specials" : "Season \(season.seasonNumber)")
                                .font(.subheadline)

                            Spacer()

                            if let stats = season.statistics {
                                let fileCount = stats.episodeFileCount ?? 0
                                let total = stats.totalEpisodeCount ?? 0
                                Text("\(fileCount)/\(total)")
                                    .font(.caption)
                                    .foregroundStyle(fileCount == total && total > 0 ? .green : .secondary)

                                if let pct = stats.percentOfEpisodes {
                                    ProgressView(value: pct / 100)
                                        .frame(width: 60)
                                }
                            }

                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedSeason = season }
                        .padding(.vertical, 10)
                    }
                }
            }

            HStack(spacing: 12) {
                Button {
                    showManualSearch = true
                } label: {
                    Label("Search Series", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .sheet(isPresented: $showManualSearch) {
                    ManualSearchView(
                        title: "Search: \(series.title)",
                        fetchReleases: {
                            try await ArrService.shared.fetchSonarrReleases(settings.config(for: .sonarr), seriesId: series.id)
                        },
                        grabRelease: { release in
                            try await ArrService.shared.grabSonarrRelease(settings.config(for: .sonarr), guid: release.guid, indexerId: release.indexerId)
                        }
                    )
                }

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 8)
        }
        .padding()
    }

    private func statBadge(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
