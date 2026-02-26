import SwiftUI

// MARK: - Movie Lookup

struct MovieLookupView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var results: [RadarrMovie] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var errorMessage: String?
    @State private var selectedMovie: RadarrMovie?

    private var config: ServerConfig { settings.config(for: .radarr) }

    var body: some View {
        NavigationStack {
            Group {
                if isSearching {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !hasSearched {
                    ContentUnavailableView(
                        "Search for a Movie",
                        systemImage: "film.stack",
                        description: Text("Enter a title or TMDB ID above.")
                    )
                } else if let error = errorMessage {
                    ContentUnavailableView(
                        "Search Failed",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        ForEach(Array(results.enumerated()), id: \.offset) { _, movie in
                            Button {
                                guard movie.id == 0 else { return }
                                selectedMovie = movie
                            } label: {
                                MovieLookupRow(movie: movie, config: config)
                            }
                            .buttonStyle(.plain)
                            .disabled(movie.id > 0)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Add Movie")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Title or TMDB ID"
            )
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)
            .onSubmit(of: .search) {
                Task { await performSearch() }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(item: $selectedMovie) { movie in
                AddMovieSheet(movie: movie)
            }
        }
    }

    private func performSearch() async {
        let term = searchText.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return }
        isSearching = true
        hasSearched = true
        errorMessage = nil
        results = []
        do {
            results = try await ArrService.shared.lookupRadarrMovie(config, term: term)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSearching = false
    }
}

private struct MovieLookupRow: View {
    let movie: RadarrMovie
    let config: ServerConfig

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let url = movie.posterURL(baseURL: config.baseURL) {
                    CachedAsyncImage(url: url)
                } else {
                    Color(.secondarySystemBackground)
                        .overlay { Image(systemName: "film").foregroundStyle(.secondary) }
                }
            }
            .frame(width: 44, height: 66)
            .clipShape(.rect(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 3) {
                Text(movie.title)
                    .font(.headline)
                    .lineLimit(2)
                if let year = movie.year {
                    Text(String(year))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let overview = movie.overview {
                    Text(overview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            if movie.id > 0 {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel("Already in library")
            }
        }
        .padding(.vertical, 4)
        .opacity(movie.id > 0 ? 0.5 : 1)
    }
}

// MARK: - Series Lookup

struct SeriesLookupView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var results: [SonarrSeries] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var errorMessage: String?
    @State private var selectedSeries: SonarrSeries?

    private var config: ServerConfig { settings.config(for: .sonarr) }

    var body: some View {
        NavigationStack {
            Group {
                if isSearching {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !hasSearched {
                    ContentUnavailableView(
                        "Search for a TV Show",
                        systemImage: "tv",
                        description: Text("Enter a title or TVDB ID above.")
                    )
                } else if let error = errorMessage {
                    ContentUnavailableView(
                        "Search Failed",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        ForEach(Array(results.enumerated()), id: \.offset) { _, series in
                            Button {
                                guard series.id == 0 else { return }
                                selectedSeries = series
                            } label: {
                                SeriesLookupRow(series: series, config: config)
                            }
                            .buttonStyle(.plain)
                            .disabled(series.id > 0)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Add TV Show")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Title or TVDB ID"
            )
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)
            .onSubmit(of: .search) {
                Task { await performSearch() }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(item: $selectedSeries) { series in
                AddSeriesSheet(series: series)
            }
        }
    }

    private func performSearch() async {
        let term = searchText.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return }
        isSearching = true
        hasSearched = true
        errorMessage = nil
        results = []
        do {
            results = try await ArrService.shared.lookupSonarrSeries(config, term: term)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSearching = false
    }
}

private struct SeriesLookupRow: View {
    let series: SonarrSeries
    let config: ServerConfig

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let url = series.posterURL(baseURL: config.baseURL) {
                    CachedAsyncImage(url: url)
                } else {
                    Color(.secondarySystemBackground)
                        .overlay { Image(systemName: "tv").foregroundStyle(.secondary) }
                }
            }
            .frame(width: 44, height: 66)
            .clipShape(.rect(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 3) {
                Text(series.title)
                    .font(.headline)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if let year = series.year { Text(String(year)) }
                    if let network = series.network { Text(network) }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                if let overview = series.overview {
                    Text(overview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            if series.id > 0 {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel("Already in library")
            }
        }
        .padding(.vertical, 4)
        .opacity(series.id > 0 ? 0.5 : 1)
    }
}

// MARK: - Artist Lookup

struct ArtistLookupView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var results: [LidarrArtist] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var errorMessage: String?
    @State private var selectedArtist: LidarrArtist?

    private var config: ServerConfig { settings.config(for: .lidarr) }

    var body: some View {
        NavigationStack {
            Group {
                if isSearching {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !hasSearched {
                    ContentUnavailableView(
                        "Search for an Artist",
                        systemImage: "music.mic",
                        description: Text("Enter an artist name above.")
                    )
                } else if let error = errorMessage {
                    ContentUnavailableView(
                        "Search Failed",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        ForEach(Array(results.enumerated()), id: \.offset) { _, artist in
                            Button {
                                guard artist.id == 0 else { return }
                                selectedArtist = artist
                            } label: {
                                ArtistLookupRow(artist: artist, config: config)
                            }
                            .buttonStyle(.plain)
                            .disabled(artist.id > 0)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Add Artist")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Artist name"
            )
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)
            .onSubmit(of: .search) {
                Task { await performSearch() }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(item: $selectedArtist) { artist in
                AddArtistSheet(artist: artist)
            }
        }
    }

    private func performSearch() async {
        let term = searchText.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return }
        isSearching = true
        hasSearched = true
        errorMessage = nil
        results = []
        do {
            results = try await ArrService.shared.lookupLidarr(config, term: term)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSearching = false
    }
}

private struct ArtistLookupRow: View {
    let artist: LidarrArtist
    let config: ServerConfig

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let url = artist.posterURL(config: config) {
                    CachedAsyncImage(url: url)
                } else {
                    Color(.secondarySystemBackground)
                        .overlay { Image(systemName: "music.mic").foregroundStyle(.secondary) }
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(.circle)

            VStack(alignment: .leading, spacing: 3) {
                Text(artist.artistName ?? "Unknown")
                    .font(.headline)
                    .lineLimit(1)
                if let overview = artist.overview {
                    Text(overview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            if artist.id > 0 {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel("Already in library")
            }
        }
        .padding(.vertical, 4)
        .opacity(artist.id > 0 ? 0.5 : 1)
    }
}
