import SwiftUI

struct SearchView: View {
    @Environment(SettingsStore.self) private var settings
    @State private var viewModel = SearchViewModel()
    @State private var selectedMovie: RadarrMovie?
    @State private var selectedSeries: SonarrSeries?
    @State private var selectedArtist: LidarrArtist?

    private let columns = [
        GridItem(.adaptive(minimum: 110), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isSearching {
                    ProgressView("Searching...")
                } else if viewModel.searchText.isEmpty {
                    searchPlaceholder
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView {
                        Label("Search Error", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    }
                } else {
                    searchResults
                }
            }
            .navigationTitle("Search")
            .searchable(text: $viewModel.searchText, prompt: "Search for media to add...")
            .searchScopes($viewModel.searchScope) {
                ForEach(SearchViewModel.SearchScope.allCases, id: \.self) { scope in
                    Text(scope.rawValue).tag(scope)
                }
            }
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)
            .onSubmit(of: .search) {
                Task { await viewModel.search(settings: settings) }
            }
            .sheet(item: $selectedMovie) { movie in
                AddMovieSheet(movie: movie)
            }
            .sheet(item: $selectedSeries) { series in
                AddSeriesSheet(series: series)
            }
            .sheet(item: $selectedArtist) { artist in
                AddArtistSheet(artist: artist)
            }
        }
    }

    private var searchPlaceholder: some View {
        ContentUnavailableView {
            Label("Search Indexers", systemImage: "magnifyingglass")
        } description: {
            Text("Search for movies, TV shows, or music to add to your library.")
        }
    }

    private var searchResults: some View {
        ScrollView {
            switch viewModel.searchScope {
            case .movies:
                if viewModel.movieResults.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                        .padding(.top, 60)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.movieResults) { movie in
                            Button {
                                selectedMovie = movie
                            } label: {
                                PosterGridView(
                                    imageURL: movie.posterURL(baseURL: settings.config(for: .radarr).baseURL),
                                    title: movie.title,
                                    subtitle: movie.year.map(String.init),
                                    badge: movie.id > 0 && movie.hasFile ? "In Library" : nil,
                                    isMonitored: true
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            case .tvShows:
                if viewModel.seriesResults.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                        .padding(.top, 60)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.seriesResults) { show in
                            Button {
                                selectedSeries = show
                            } label: {
                                PosterGridView(
                                    imageURL: show.posterURL(baseURL: settings.config(for: .sonarr).baseURL),
                                    title: show.title,
                                    subtitle: [show.year.map(String.init), show.network]
                                        .compactMap { $0 }.joined(separator: " · "),
                                    badge: nil,
                                    isMonitored: true
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            case .music:
                if viewModel.artistResults.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                        .padding(.top, 60)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.artistResults) { artist in
                            Button {
                                selectedArtist = artist
                            } label: {
                                PosterGridView(
                                    imageURL: artist.posterURL(config: settings.config(for: .lidarr)),
                                    title: artist.artistName ?? "Unknown",
                                    subtitle: nil,
                                    badge: nil,
                                    isMonitored: true
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
        }
    }
}
