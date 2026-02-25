import SwiftUI

struct ArtistDetailSheet: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss
    let artist: LidarrArtist
    let viewModel: LidarrViewModel

    @State private var showDeleteConfirmation: Bool = false
    @State private var localMonitored: Bool
    @State private var artistAlbums: [LidarrAlbum] = []
    @State private var isLoadingAlbums: Bool = false
    @State private var selectedAlbum: LidarrAlbum?

    init(artist: LidarrArtist, viewModel: LidarrViewModel) {
        self.artist = artist
        self.viewModel = viewModel
        _localMonitored = State(initialValue: artist.monitored)
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
                    discographySection
                }
            }
            .navigationTitle(artist.artistName ?? "Artist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            localMonitored.toggle()
                            Task {
                                let ok = await viewModel.toggleArtistMonitored(lidarrConfig, artist: artist)
                                if !ok { localMonitored.toggle() }
                            }
                        } label: {
                            Image(systemName: localMonitored ? "eye.fill" : "eye.slash")
                        }

                        Button("Done") { dismiss() }
                    }
                }
            }
            .confirmationDialog("Delete Artist", isPresented: $showDeleteConfirmation) {
                Button("Delete Artist", role: .destructive) {
                    Task {
                        await viewModel.deleteArtist(settings.config(for: .lidarr), artist: artist)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .task { await loadAlbums() }
            .sheet(item: $selectedAlbum) { album in
                AlbumDetailSheet(album: album, viewModel: viewModel)
            }
        }
    }

    private func loadAlbums() async {
        guard artistAlbums.isEmpty else { return }
        isLoadingAlbums = true
        if let albums = try? await ArrService.shared.fetchLidarrAlbums(lidarrConfig, artistId: artist.id) {
            artistAlbums = albums.sorted {
                let l = $0.releaseDate ?? ""; let r = $1.releaseDate ?? ""
                return l != r ? l > r : ($0.title ?? "") < ($1.title ?? "")
            }
        }
        isLoadingAlbums = false
    }

    private var headerSection: some View {
        Color(.secondarySystemBackground)
            .frame(height: 200)
            .overlay {
                if let url = artist.fanartURL(config: lidarrConfig) {
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
                        .frame(width: 80, height: 80)
                        .overlay {
                            if let url = artist.posterURL(config: lidarrConfig) {
                                CachedAsyncImage(url: url)
                                    .allowsHitTesting(false)
                            }
                        }
                        .clipShape(.rect(cornerRadius: 8))
                        .shadow(radius: 4)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(artist.artistName ?? "Unknown Artist")
                            .font(.title3.bold())
                            .lineLimit(2)

                        if let stats = artist.statistics {
                            HStack(spacing: 8) {
                                if let albums = stats.albumCount {
                                    Text("\(albums) albums")
                                }
                                if let tracks = stats.trackFileCount {
                                    Text("\(tracks) tracks")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let overview = artist.overview, !overview.isEmpty {
                Text(overview)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            if let genres = artist.genres, !genres.isEmpty {
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

            if let stats = artist.statistics, let size = stats.sizeOnDisk, size > 0 {
                HStack {
                    Label("Size on Disk", systemImage: "internaldrive")
                    Spacer()
                    Text(FormatUtils.fileSize(size))
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
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

    private var discographySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Discography")
                    .font(.headline)
                if isLoadingAlbums {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 12)

            if !artistAlbums.isEmpty {
                ForEach(artistAlbums) { album in
                    albumRow(album)
                    if album.id != artistAlbums.last?.id {
                        Divider().padding(.leading, 78)
                    }
                }
            }
        }
        .padding(.bottom)
    }

    private func albumRow(_ album: LidarrAlbum) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(album.monitored ? Color.accentColor : Color(.tertiaryLabel))
                .frame(width: 6, height: 6)

            Color(.secondarySystemBackground)
                .frame(width: 50, height: 50)
                .overlay {
                    if let url = album.coverURL(config: lidarrConfig) {
                        CachedAsyncImage(url: url)
                            .allowsHitTesting(false)
                    }
                }
                .clipShape(.rect(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(album.title ?? "Unknown Album")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                if let date = album.releaseDate {
                    Text(String(date.prefix(4)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let stats = album.statistics,
               let fileCount = stats.trackFileCount,
               let totalCount = stats.totalTrackCount {
                Text("\(fileCount)/\(totalCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(fileCount >= totalCount && totalCount > 0 ? .green : .secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture { selectedAlbum = album }
    }
}
