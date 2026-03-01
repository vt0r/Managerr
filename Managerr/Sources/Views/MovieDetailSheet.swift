import SwiftUI

struct MovieDetailSheet: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss
    let movie: RadarrMovie
    let viewModel: RadarrViewModel

    @State private var showDeleteConfirmation: Bool = false
    @State private var localMonitored: Bool
    @State private var showManualSearch: Bool = false

    init(movie: RadarrMovie, viewModel: RadarrViewModel) {
        self.movie = movie
        self.viewModel = viewModel
        _localMonitored = State(initialValue: movie.monitored)
    }

    private var baseURL: URL? {
        settings.config(for: .radarr).baseURL
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    detailsSection
                }
            }
            .navigationTitle(movie.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            localMonitored.toggle()
                            Task {
                                let ok = await viewModel.toggleMonitored(settings.config(for: .radarr), movie: movie)
                                if !ok { localMonitored.toggle() }
                            }
                        } label: {
                            Image(systemName: localMonitored ? "eye.fill" : "eye.slash")
                        }
                        .accessibilityLabel(localMonitored ? "Monitored" : "Not monitored")
                        .accessibilityHint("Toggles monitoring for this movie")

                        Button("Done") { dismiss() }
                    }
                }
            }
            .confirmationDialog("Delete Movie", isPresented: $showDeleteConfirmation) {
                Button("Delete from Radarr", role: .destructive) {
                    Task {
                        await viewModel.deleteMovie(settings.config(for: .radarr), movie: movie, deleteFiles: false)
                        dismiss()
                    }
                }
                Button("Delete with Files", role: .destructive) {
                    Task {
                        await viewModel.deleteMovie(settings.config(for: .radarr), movie: movie, deleteFiles: true)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var headerSection: some View {
        Color(.secondarySystemBackground)
            .frame(height: 220)
            .overlay {
                if let url = movie.fanartURL(baseURL: baseURL) {
                    CachedAsyncImage(url: url)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
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
                            if let url = movie.posterURL(baseURL: baseURL) {
                                CachedAsyncImage(url: url)
                                    .allowsHitTesting(false)
                            }
                        }
                        .clipShape(.rect(cornerRadius: 8))
                        .shadow(radius: 4)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(movie.title)
                            .font(.title3.bold())
                            .lineLimit(2)

                        HStack(spacing: 8) {
                            if let year = movie.year {
                                Text(String(year))
                            }
                            if let runtime = movie.runtime {
                                Text("\(runtime) min")
                            }
                            if let cert = movie.certification, !cert.isEmpty {
                                Text(cert)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.secondary.opacity(0.6), lineWidth: 1))
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        if let badge = movie.gridBadge {
                            Text(badge)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(badge == "MISSING" ? Color.red.opacity(0.2) : Color.orange.opacity(0.2), in: Capsule())
                                .foregroundStyle(badge == "MISSING" ? .red : .orange)
                        } else if movie.hasFile {
                            Label("On Disk", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }
                .padding()
            }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let ratings = movie.ratings {
                ratingsRow(ratings)
            }

            if let overview = movie.overview, !overview.isEmpty {
                Text(overview)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            if let genres = movie.genres, !genres.isEmpty {
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

            HStack(spacing: 12) {
                Button {
                    showManualSearch = true
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .sheet(isPresented: $showManualSearch) {
                    ManualSearchView(
                        title: "Search: \(movie.title)",
                        fetchReleases: {
                            try await ArrService.shared.fetchRadarrReleases(settings.config(for: .radarr), movieId: movie.id)
                        },
                        grabRelease: { release in
                            try await ArrService.shared.grabRadarrRelease(settings.config(for: .radarr), guid: release.guid, indexerId: release.indexerId)
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

            releaseInfoSection

            if let sizeOnDisk = movie.sizeOnDisk, sizeOnDisk > 0 {
                HStack {
                    Label("Size", systemImage: "internaldrive")
                    Spacer()
                    Text(FormatUtils.fileSize(sizeOnDisk))
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            if let quality = movie.movieFile?.quality?.quality?.name {
                HStack {
                    Label("Quality", systemImage: "sparkles.tv")
                    Spacer()
                    Text(quality)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private var releaseInfoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let status = movie.status, !status.isEmpty {
                HStack {
                    Label("Status", systemImage: "info.circle")
                    Spacer()
                    Text(formattedStatus(status))
                        .foregroundStyle(statusColor(status))
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            if let date = formatDate(movie.inCinemas) {
                HStack {
                    Label("In Cinemas", systemImage: "film")
                    Spacer()
                    Text(date)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            if let date = formatDate(movie.digitalRelease) {
                HStack {
                    Label("Digital", systemImage: "play.tv")
                    Spacer()
                    Text(date)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            if let date = formatDate(movie.physicalRelease) {
                HStack {
                    Label("Physical", systemImage: "opticaldisc")
                    Spacer()
                    Text(date)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            if let date = formatDate(movie.added) {
                HStack {
                    Label("Added", systemImage: "calendar.badge.plus")
                    Spacer()
                    Text(date)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func formatDate(_ iso: String?) -> String? {
        guard let iso, !iso.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: iso)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: iso)
        }
        guard let date else { return nil }
        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .none
        return display.string(from: date)
    }

    private func formattedStatus(_ status: String) -> String {
        switch status {
        case "tba": return "TBA"
        case "announced": return "Announced"
        case "inCinemas": return "In Cinemas"
        case "released": return "Released"
        case "deleted": return "Deleted"
        default: return status.capitalized
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "released": return .green
        case "inCinemas": return .orange
        case "announced": return .blue
        default: return .secondary
        }
    }

    private func ratingsRow(_ ratings: RadarrRatings) -> some View {
        HStack(spacing: 16) {
            if let imdb = ratings.imdb?.value, imdb > 0 {
                VStack(spacing: 2) {
                    Text("IMDb")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f", imdb))
                        .font(.title3.bold())
                        .foregroundStyle(.yellow)
                }
            }
            if let tmdb = ratings.tmdb?.value, tmdb > 0 {
                VStack(spacing: 2) {
                    Text("TMDB")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f%%", tmdb * 10))
                        .font(.title3.bold())
                        .foregroundStyle(.green)
                }
            }
            if let rt = ratings.rottenTomatoes?.value, rt > 0 {
                VStack(spacing: 2) {
                    Text("RT")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f%%", rt))
                        .font(.title3.bold())
                        .foregroundStyle(.red)
                }
            }
        }
    }
}
