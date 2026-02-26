import SwiftUI

struct RadarrView: View {
    @Environment(SettingsStore.self) private var settings
    @State private var viewModel = RadarrViewModel()
    @State private var selectedMovie: RadarrMovie?
    @State private var showAddSheet = false

    private let columns = [
        GridItem(.adaptive(minimum: 110), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if !settings.isConfigured(.radarr) {
                    notConfiguredView
                } else if viewModel.isLoading && viewModel.movies.isEmpty {
                    ProgressView("Loading movies...")
                } else if let error = viewModel.errorMessage, viewModel.movies.isEmpty {
                    errorView(error)
                } else {
                    movieGrid
                }
            }
            .navigationTitle("Movies")
            .searchable(text: $viewModel.searchText, prompt: "Search movies")
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort", selection: $viewModel.sortOrder) {
                            ForEach(RadarrViewModel.SortOrder.allCases, id: \.self) { order in
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
                        Task { await viewModel.fetchMovies(settings.config(for: .radarr)) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh")
                }
            }
            .refreshable {
                await viewModel.fetchMovies(settings.config(for: .radarr))
            }
            .task {
                if viewModel.movies.isEmpty && settings.isConfigured(.radarr) {
                    await viewModel.fetchMovies(settings.config(for: .radarr))
                }
            }
            .sheet(item: $selectedMovie) { movie in
                MovieDetailSheet(movie: movie, viewModel: viewModel)
            }
            .sheet(isPresented: $showAddSheet) {
                MovieLookupView()
            }
            .overlay(alignment: .bottomTrailing) {
                if settings.isConfigured(.radarr) {
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
                    .accessibilityLabel("Add Movie")
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    private var baseURL: URL? {
        settings.config(for: .radarr).baseURL
    }

    private var movieGrid: some View {
        ScrollView {
            if viewModel.filteredMovies.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
                    .padding(.top, 60)
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.filteredMovies) { movie in
                        Button {
                            selectedMovie = movie
                        } label: {
                            PosterGridView(
                                imageURL: movie.posterURL(baseURL: baseURL),
                                title: movie.title,
                                subtitle: [movie.year.map(String.init), movie.runtime.map { "\($0)m" }]
                                    .compactMap { $0 }.joined(separator: " · "),
                                badge: movie.gridBadge,
                                isMonitored: movie.monitored
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 88)
            }
        }
    }

    private var notConfiguredView: some View {
        ContentUnavailableView {
            Label("Radarr Not Configured", systemImage: "film")
        } description: {
            Text("Add your Radarr server URL and API key in Settings to get started.")
        }
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Connection Error", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Retry") {
                Task { await viewModel.fetchMovies(settings.config(for: .radarr)) }
            }
            .buttonStyle(.bordered)
        }
    }
}
