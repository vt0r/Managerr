import SwiftUI

struct AlbumDetailSheet: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss
    let album: LidarrAlbum
    var viewModel: LidarrViewModel? = nil
    @State private var localMonitored: Bool
    @State private var showManualSearch: Bool = false
    @State private var tracks: [LidarrTrack] = []
    @State private var isLoadingTracks: Bool = false
    @State private var showAutoSearchConfirm: Bool = false

    init(album: LidarrAlbum, viewModel: LidarrViewModel? = nil) {
        self.album = album
        self.viewModel = viewModel
        _localMonitored = State(initialValue: album.monitored)
    }

    private var lidarrConfig: ServerConfig {
        settings.config(for: .lidarr)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 16) {
                        Color(.secondarySystemBackground)
                            .frame(width: 120, height: 120)
                            .overlay {
                                if let url = album.coverURL(config: lidarrConfig) {
                                    CachedAsyncImage(url: url)
                                        .allowsHitTesting(false)
                                }
                            }
                            .clipShape(.rect(cornerRadius: 10))

                        VStack(alignment: .leading, spacing: 6) {
                            Text(album.title ?? "Unknown Album")
                                .font(.title3.bold())
                                .lineLimit(3)

                            if let artist = album.artist?.artistName {
                                Text(artist)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 8) {
                                if let albumType = album.albumType {
                                    Text(albumType)
                                        .font(.caption.weight(.medium))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color(.tertiarySystemBackground), in: Capsule())
                                }
                                if let date = album.releaseDate {
                                    Text(String(date.prefix(4)))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            if let ratings = album.ratings, let value = ratings.value, value > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(.yellow)
                                        .font(.caption)
                                    Text(String(format: "%.1f", value))
                                        .font(.subheadline.bold())
                                }
                            }
                        }
                    }

                    if let overview = album.overview, !overview.isEmpty {
                        Text(overview)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    if let genres = album.genres, !genres.isEmpty {
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

                    if let stats = album.statistics {
                        VStack(spacing: 8) {
                            if let trackCount = stats.trackCount, let fileCount = stats.trackFileCount {
                                HStack {
                                    Label("Tracks", systemImage: "music.note")
                                    Spacer()
                                    Text("\(fileCount)/\(trackCount)")
                                }
                            }
                            if let size = stats.sizeOnDisk, size > 0 {
                                HStack {
                                    Label("Size", systemImage: "internaldrive")
                                    Spacer()
                                    Text(FormatUtils.fileSize(size))
                                }
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }

                    tracksSection

                    if let viewModel {
                        HStack(spacing: 12) {
                            Button { showAutoSearchConfirm = true } label: {
                                Label("Auto Search", systemImage: "wand.and.stars").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .alert("Search for Album?", isPresented: $showAutoSearchConfirm) {
                                Button("Search") {
                                    Task { await viewModel.searchAlbum(lidarrConfig, albumId: album.id) }
                                }
                                Button("Cancel", role: .cancel) {}
                            } message: {
                                Text("Lidarr will search all configured indexers for \"\(album.title ?? "this album")\".")
                            }

                            Button { showManualSearch = true } label: {
                                Label("Manual Search", systemImage: "magnifyingglass").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .sheet(isPresented: $showManualSearch) {
                                ManualSearchView(
                                    title: "Search: \(album.title ?? "Album")",
                                    fetchReleases: {
                                        try await ArrService.shared.fetchLidarrReleases(lidarrConfig, albumId: album.id)
                                    },
                                    grabRelease: { release in
                                        try await ArrService.shared.grabLidarrRelease(lidarrConfig, guid: release.guid, indexerId: release.indexerId)
                                    }
                                )
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding()
            }
            .navigationTitle("Album Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        if let viewModel {
                            Button {
                                localMonitored.toggle()
                                Task {
                                    let ok = await viewModel.toggleAlbumMonitored(lidarrConfig, album: album)
                                    if !ok { localMonitored.toggle() }
                                }
                            } label: {
                                Image(systemName: localMonitored ? "eye.fill" : "eye.slash")
                            }
                            .accessibilityLabel(localMonitored ? "Monitored" : "Not monitored")
                            .accessibilityHint("Toggles monitoring for this album")
                        }

                        Button("Done") { dismiss() }
                    }
                }
            }
            .task { await loadTracks() }
        }
    }

    private func loadTracks() async {
        guard tracks.isEmpty else { return }
        isLoadingTracks = true
        if let fetched = try? await ArrService.shared.fetchLidarrTracks(lidarrConfig, albumId: album.id) {
            tracks = fetched.sorted {
                let lM = $0.mediumNumber ?? 1; let rM = $1.mediumNumber ?? 1
                return lM != rM ? lM < rM : ($0.trackNumber ?? 0) < ($1.trackNumber ?? 0)
            }
        }
        isLoadingTracks = false
    }

    private var tracksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tracks")
                    .font(.headline)
                if isLoadingTracks {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            let discNumbers = Set(tracks.compactMap { $0.mediumNumber ?? 1 }).sorted()
            let isMultiDisc = discNumbers.count > 1

            if tracks.isEmpty && !isLoadingTracks {
                Text("No tracks found")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            } else if isMultiDisc {
                ForEach(discNumbers, id: \.self) { disc in
                    Text("Disc \(disc)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, disc == discNumbers.first ? 0 : 8)

                    let discTracks = tracks.filter { ($0.mediumNumber ?? 1) == disc }
                    ForEach(discTracks) { track in
                        trackRow(track)
                        if track.id != discTracks.last?.id {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
            } else {
                ForEach(tracks) { track in
                    trackRow(track)
                    if track.id != tracks.last?.id {
                        Divider().padding(.leading, 44)
                    }
                }
            }
        }
    }

    private func trackRow(_ track: LidarrTrack) -> some View {
        HStack(spacing: 8) {
            Text("\(track.trackNumber ?? 0)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)

            Text(track.title ?? "Unknown Track")
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)

            Text(FormatUtils.trackDuration(track.duration))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Image(systemName: track.hasFile ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(track.hasFile ? .green : Color(.tertiaryLabel))
                .font(.subheadline)
        }
    }
}
