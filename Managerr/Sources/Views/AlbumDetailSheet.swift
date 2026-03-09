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
    @State private var showDeleteAlbumFilesConfirm: Bool = false
    @State private var deletingTrack: LidarrTrack?
    @State private var deletedTrackFileIds: Set<Int> = []

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
                VStack(spacing: 0) {
                    headerSection
                    detailsSection
                    tracksSection
                        .padding(.horizontal)
                        .padding(.bottom)
                }
            }
            .navigationTitle(album.title ?? "Album")
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
                                    await viewModel.fetchArtistsSilently(lidarrConfig)
                                }
                            } label: {
                                Image(systemName: localMonitored ? "eye.fill" : "eye.slash")
                            }
                            .accessibilityLabel(localMonitored ? "Monitored" : "Not monitored")
                            .accessibilityHint("Toggles monitoring for this album")
                        }

                        if viewModel != nil {
                            Menu {
                                Button(role: .destructive) {
                                    showDeleteAlbumFilesConfirm = true
                                } label: {
                                    Label("Delete Album Files", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }

                        Button("Done") { dismiss() }
                    }
                }
            }
            .task { await loadTracks() }
            .alert("Delete Album Files?", isPresented: $showDeleteAlbumFilesConfirm) {
                Button("Delete", role: .destructive) {
                    let fileIds = tracks.compactMap { t -> Int? in
                        guard t.hasFile, let fid = t.trackFileId, !deletedTrackFileIds.contains(fid) else { return nil }
                        return fid
                    }
                    if let vm = viewModel {
                        Task {
                            await vm.deleteAlbumFiles(lidarrConfig, trackFileIds: fileIds)
                            fileIds.forEach { deletedTrackFileIds.insert($0) }
                            await vm.fetchArtistsSilently(lidarrConfig)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Delete all downloaded files for \"\(album.title ?? "this album")\"? This cannot be undone.")
            }
            .alert(
                "Delete Track File?",
                isPresented: Binding(get: { deletingTrack != nil }, set: { if !$0 { deletingTrack = nil } }),
                presenting: deletingTrack
            ) { track in
                Button("Delete", role: .destructive) {
                    guard let fileId = track.trackFileId, let vm = viewModel else { deletingTrack = nil; return }
                    Task {
                        await vm.deleteTrackFile(lidarrConfig, trackFileId: fileId)
                        deletedTrackFileIds.insert(fileId)
                        await vm.fetchArtistsSilently(lidarrConfig)
                    }
                    deletingTrack = nil
                }
                Button("Cancel", role: .cancel) { deletingTrack = nil }
            } message: { track in
                Text("Delete the file for \"\(track.title ?? "this track")\"? This cannot be undone.")
            }
        }
    }

    private var headerSection: some View {
        Color(.secondarySystemBackground)
            .frame(height: 200)
            .overlay {
                if let url = album.coverURL(config: lidarrConfig) {
                    CachedAsyncImage(url: url)
                        .blur(radius: 20)
                        .scaleEffect(1.3)
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
                        .frame(width: 80, height: 80)
                        .overlay {
                            if let url = album.coverURL(config: lidarrConfig) {
                                CachedAsyncImage(url: url)
                                    .allowsHitTesting(false)
                            }
                        }
                        .clipShape(.rect(cornerRadius: 8))
                        .shadow(radius: 4)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(album.title ?? "Unknown Album")
                            .font(.title3.bold())
                            .lineLimit(2)

                        HStack(spacing: 8) {
                            if let artist = album.artist?.artistName { Text(artist) }
                            if let albumType = album.albumType { Text(albumType) }
                            if let date = album.releaseDate { Text(String(date.prefix(4))) }
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
            if let stats = album.statistics {
                HStack(spacing: 24) {
                    if let trackCount = stats.trackCount, let fileCount = stats.trackFileCount {
                        statBadge(value: "\(fileCount)/\(trackCount)", label: "Tracks")
                    }
                    if let size = stats.sizeOnDisk, size > 0 {
                        statBadge(value: FormatUtils.fileSize(size), label: "Size")
                    }
                }
            }

            if let ratings = album.ratings, let value = ratings.value, value > 0 {
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

    private func statBadge(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func loadTracks() async {
        guard tracks.isEmpty else { return }
        isLoadingTracks = true
        if let fetched = try? await ArrService.shared.fetchLidarrTracks(lidarrConfig, albumId: album.id) {
            tracks = fetched.sorted {
                let lM = $0.mediumNumber ?? 1; let rM = $1.mediumNumber ?? 1
                if lM != rM { return lM < rM }
                let lN = Int($0.trackNumber ?? "") ?? 0
                let rN = Int($1.trackNumber ?? "") ?? 0
                return lN < rN
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
                VStack(spacing: 0) {
                    ForEach(discNumbers, id: \.self) { disc in
                        HStack {
                            Text("Disc \(disc)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)

                        let discTracks = tracks.filter { ($0.mediumNumber ?? 1) == disc }
                        ForEach(discTracks) { track in
                            trackRow(track)
                            if track.id != discTracks.last?.id {
                                Divider().padding(.leading, 44)
                            }
                        }

                        if disc != discNumbers.last {
                            Divider()
                        }
                    }
                }
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            } else {
                VStack(spacing: 0) {
                    ForEach(tracks) { track in
                        trackRow(track)
                        if track.id != tracks.last?.id {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func trackRow(_ track: LidarrTrack) -> some View {
        let isImported = track.hasFile && track.trackFileId != nil && !(track.trackFileId.map { deletedTrackFileIds.contains($0) } ?? false)
        let isDownloading = track.hasFile && track.trackFileId == nil
        return HStack(spacing: 8) {
            Text(track.trackNumber ?? "?")
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

            Image(systemName: isImported ? "checkmark.circle.fill" : isDownloading ? "arrow.down.circle.fill" : "circle")
                .foregroundStyle(isImported ? .green : isDownloading ? .orange : Color(.tertiaryLabel))
                .font(.subheadline)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contextMenu {
            if isImported {
                Button(role: .destructive) {
                    deletingTrack = track
                } label: {
                    Label("Delete File", systemImage: "trash")
                }
            }
        }
    }
}
