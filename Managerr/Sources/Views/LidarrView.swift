import SwiftUI

struct LidarrView: View {
    @Environment(SettingsStore.self) private var settings
    @State private var viewModel = LidarrViewModel()
    @State private var selectedArtist: LidarrArtist?
    @State private var selectedAlbum: LidarrAlbum?
    @State private var showAddSheet = false

    private let columns = [
        GridItem(.adaptive(minimum: 110), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if !settings.isConfigured(.lidarr) {
                    notConfiguredView
                } else if viewModel.isLoading && viewModel.artists.isEmpty {
                    ProgressView("Loading music...")
                } else if let error = viewModel.errorMessage, viewModel.artists.isEmpty {
                    errorView(error)
                } else {
                    musicContent
                }
            }
            .navigationTitle("Music")
            .searchable(text: $viewModel.searchText, prompt: "Search music")
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Picker("View", selection: $viewModel.viewMode) {
                        ForEach(LidarrViewModel.ViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort", selection: $viewModel.sortOrder) {
                            ForEach(LidarrViewModel.SortOrder.allCases, id: \.self) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .accessibilityLabel("Sort")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.fetchAll(settings.config(for: .lidarr)) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh")
                }
            }
            .refreshable {
                await viewModel.fetchAll(settings.config(for: .lidarr))
            }
            .task {
                if viewModel.artists.isEmpty && settings.isConfigured(.lidarr) {
                    await viewModel.fetchAll(settings.config(for: .lidarr))
                }
            }
            .sheet(item: $selectedArtist) { artist in
                ArtistDetailSheet(artist: artist, viewModel: viewModel)
            }
            .sheet(item: $selectedAlbum) { album in
                AlbumDetailSheet(album: album, viewModel: viewModel)
            }
            .sheet(isPresented: $showAddSheet) {
                ArtistLookupView()
            }
            .overlay(alignment: .bottomTrailing) {
                if settings.isConfigured(.lidarr) &&
                   !(viewModel.isLoading && viewModel.artists.isEmpty) &&
                   !(viewModel.errorMessage != nil && viewModel.artists.isEmpty) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(.tint)
                            .clipShape(.circle)
                            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                    }
                    .accessibilityLabel("Add Artist")
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    private var musicContent: some View {
        ScrollView {
            switch viewModel.viewMode {
            case .albums:
                if viewModel.filteredAlbums.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                        .padding(.top, 60)
                } else {
                    albumGrid
                }
            case .artists:
                if viewModel.filteredArtists.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                        .padding(.top, 60)
                } else {
                    artistGrid
                }
            }
        }
    }

    private var albumGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(viewModel.filteredAlbums) { album in
                Button {
                    selectedAlbum = album
                } label: {
                    PosterGridView(
                        imageURL: album.coverURL(config: settings.config(for: .lidarr)),
                        title: album.title ?? "Unknown",
                        subtitle: album.artist?.artistName,
                        badge: album.albumType,
                        isMonitored: album.monitored
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 88)
    }

    private var artistGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(viewModel.filteredArtists) { artist in
                Button {
                    selectedArtist = artist
                } label: {
                    PosterGridView(
                        imageURL: artist.posterURL(config: settings.config(for: .lidarr)),
                        title: artist.artistName ?? "Unknown",
                        subtitle: artist.statistics.map { "\($0.albumCount ?? 0) albums" },
                        badge: nil,
                        isMonitored: artist.monitored
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 88)
    }

    private var notConfiguredView: some View {
        ContentUnavailableView {
            Label("Lidarr Not Configured", systemImage: "music.note")
        } description: {
            Text("Add your Lidarr server URL and API key in Settings to get started.")
        }
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Connection Error", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Retry") {
                Task { await viewModel.fetchAll(settings.config(for: .lidarr)) }
            }
            .buttonStyle(.bordered)
        }
    }
}
