import SwiftUI

struct SonarrView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @State private var viewModel = SonarrViewModel()
    @State private var selectedSeries: SonarrSeries?
    @State private var showAddSheet = false

    private var isRefreshing: Bool { viewModel.isLoading && !viewModel.series.isEmpty }

    private let columns = [
        GridItem(.adaptive(minimum: 110), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if !settings.isConfigured(.sonarr) {
                    notConfiguredView
                } else if viewModel.isLoading && viewModel.series.isEmpty {
                    ProgressView("Loading series...")
                } else if let error = viewModel.errorMessage, viewModel.series.isEmpty {
                    errorView(error)
                } else {
                    seriesGrid
                }
            }
            .navigationTitle("TV Shows")
            .searchable(text: $viewModel.searchText, prompt: "Search series")
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort", selection: $viewModel.sortOrder) {
                            ForEach(SonarrViewModel.SortOrder.allCases, id: \.self) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .accessibilityLabel("Sort")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            Task { await viewModel.fetchSeries(settings.config(for: .sonarr)) }
                        } label: {
                            Label(isRefreshing ? "Refreshing..." : "Refresh", systemImage: "arrow.clockwise")
                        }
                        .disabled(isRefreshing)
                        .accessibilityLabel(isRefreshing ? "Refreshing" : "Refresh")
                        if let url = settings.config(for: .sonarr).baseURL {
                            Divider()
                            Button {
                                openURL(url)
                            } label: {
                                Label("Open Sonarr in Browser", systemImage: "safari")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Actions")
                }
            }
            .refreshable {
                await viewModel.fetchSeries(settings.config(for: .sonarr))
            }
            .task {
                guard settings.isConfigured(.sonarr) else { return }
                let config = settings.config(for: .sonarr)
                if viewModel.series.isEmpty {
                    await viewModel.fetchSeries(config)
                }
            }
            .sheet(item: $selectedSeries) { show in
                SeriesDetailSheet(series: show, viewModel: viewModel)
            }
            .sheet(isPresented: $showAddSheet) {
                SeriesLookupView()
            }
            .overlay(alignment: .bottomTrailing) {
                if settings.isConfigured(.sonarr) &&
                   !(viewModel.isLoading && viewModel.series.isEmpty) &&
                   !(viewModel.errorMessage != nil && viewModel.series.isEmpty) {
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
                    .accessibilityLabel("Add TV Show")
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    private var baseURL: URL? {
        settings.config(for: .sonarr).baseURL
    }

    private var seriesGrid: some View {
        ScrollView {
            if viewModel.filteredSeries.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
                    .padding(.top, 60)
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.filteredSeries) { show in
                        Button {
                            selectedSeries = show
                        } label: {
                            PosterGridView(
                                imageURL: show.posterURL(baseURL: baseURL),
                                title: show.title,
                                subtitle: [
                                    show.year.map(String.init),
                                    show.network,
                                    show.statistics.map { "\($0.episodeFileCount ?? 0)/\($0.episodeCount ?? 0) eps" }
                                ].compactMap { $0 }.joined(separator: " · "),
                                badge: show.status == "ended" ? "ENDED" : nil,
                                isMonitored: show.monitored
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
            Label("Sonarr Not Configured", systemImage: "tv")
        } description: {
            Text("Add your Sonarr server URL and API key in Settings to get started.")
        }
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Connection Error", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Retry") {
                Task { await viewModel.fetchSeries(settings.config(for: .sonarr)) }
            }
            .buttonStyle(.bordered)
        }
    }
}
