import SwiftUI

struct WantedDetailSheet: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss
    let item: WantedItem
    let filter: WantedFilter
    let viewModel: WantedViewModel

    @State private var showManualSearch = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    VStack(alignment: .leading, spacing: 20) {
                        detailsSection
                        Divider()
                        actionsSection
                    }
                    .padding()
                }
            }
            .navigationTitle(item.primaryTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showManualSearch) {
                manualSearchSheet
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(contentTypeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(filter.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(filterPillColor, in: Capsule())
            }
            Text(item.primaryTitle)
                .font(.title3.bold())
                .lineLimit(2)
            if let secondary = item.secondaryTitle {
                Text(secondary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    // MARK: - Details

    @ViewBuilder
    private var detailsSection: some View {
        switch item.content {
        case .movie(let m):  movieDetails(m)
        case .episode(let e): episodeDetails(e)
        case .album(let a):  albumDetails(a)
        }
    }

    private func movieDetails(_ movie: RadarrMovie) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let runtime = movie.runtime, runtime > 0 {
                detailRow("Runtime", value: "\(runtime) min", icon: "clock")
            }
            if let status = movie.status, !status.isEmpty {
                detailRow("Status", value: status.capitalized, icon: "info.circle")
            }
            if let genres = movie.genres, !genres.isEmpty {
                detailRow("Genres", value: genres.joined(separator: ", "), icon: "tag")
            }
            if let overview = movie.overview, !overview.isEmpty {
                overviewRow(overview)
            }
        }
    }

    private func episodeDetails(_ episode: SonarrEpisode) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            let code = String(format: "S%02dE%02d", episode.seasonNumber, episode.episodeNumber)
            detailRow("Episode", value: code, icon: "number")
            if let airDate = episode.airDate {
                detailRow("Air Date", value: airDate, icon: "calendar")
            }
            if let overview = episode.overview, !overview.isEmpty {
                overviewRow(overview)
            }
        }
    }

    private func albumDetails(_ album: LidarrAlbum) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let albumType = album.albumType, !albumType.isEmpty {
                detailRow("Type", value: albumType, icon: "opticaldisc")
            }
            if let releaseDate = album.releaseDate {
                detailRow("Release Date", value: String(releaseDate.prefix(10)), icon: "calendar")
            }
            if let overview = album.overview, !overview.isEmpty {
                overviewRow(overview)
            }
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    await viewModel.autoSearch(settings, item: item)
                    dismiss()
                }
            } label: {
                Label("Auto Search", systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                showManualSearch = true
            } label: {
                Label("Manual Search", systemImage: "list.bullet.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button(role: .destructive) {
                Task {
                    await viewModel.unmonitor(settings, item: item)
                    dismiss()
                }
            } label: {
                Label("Unmonitor", systemImage: "bookmark.slash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.top, 8)
    }

    // MARK: - Manual Search Sheet

    @ViewBuilder
    private var manualSearchSheet: some View {
        let config = settings.config(for: item.service)
        ManualSearchView(
            title: item.primaryTitle,
            fetchReleases: {
                switch item.content {
                case .movie(let m):
                    return try await ArrService.shared.fetchRadarrReleases(config, movieId: m.id)
                case .episode(let e):
                    return try await ArrService.shared.fetchSonarrEpisodeReleases(config, episodeId: e.id)
                case .album(let a):
                    return try await ArrService.shared.fetchLidarrReleases(config, albumId: a.id)
                }
            },
            grabRelease: { release in
                switch item.content {
                case .movie:
                    try await ArrService.shared.grabRadarrRelease(config, guid: release.guid, indexerId: release.indexerId)
                case .episode:
                    try await ArrService.shared.grabSonarrRelease(config, guid: release.guid, indexerId: release.indexerId)
                case .album:
                    try await ArrService.shared.grabLidarrRelease(config, guid: release.guid, indexerId: release.indexerId)
                }
            }
        )
    }

    // MARK: - Helpers

    private var contentTypeLabel: String {
        switch item.content {
        case .movie: "Movie"
        case .episode: "Episode"
        case .album: "Album"
        }
    }

    private var filterPillColor: Color {
        filter == .missing ? .orange : .yellow
    }

    private func detailRow(_ label: String, value: String, icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    private func overviewRow(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Overview", systemImage: "text.alignleft")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
