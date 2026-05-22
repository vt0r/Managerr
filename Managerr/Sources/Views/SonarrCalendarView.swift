import SwiftUI

struct SonarrCalendarView: View {
    @Environment(SettingsStore.self) private var settings
    @State private var weekStart: Date = Self.currentWeekStart()
    @State private var monthItems: [SonarrEpisode] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var monitoredOnly = false

    private static let dateParser: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let sectionFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f
    }()

    private static func currentWeekStart() -> Date {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)) ?? .now
    }

    private var displayedMonthStart: Date {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: weekStart)) ?? weekStart
    }

    private var trueWeekStart: Date {
        let cal = Calendar.current
        let offset = (cal.component(.weekday, from: weekStart) - cal.firstWeekday + 7) % 7
        return cal.date(byAdding: .day, value: -offset, to: weekStart) ?? weekStart
    }

    private var weekEnd: Date {
        Calendar.current.date(byAdding: .day, value: 7, to: trueWeekStart) ?? trueWeekStart
    }

    private var markedDays: Set<Date> {
        var days = Set<Date>()
        for episode in monthItems {
            if let airDate = episode.airDate,
               let date = Self.dateParser.date(from: airDate) {
                days.insert(Calendar.current.startOfDay(for: date))
            }
        }
        return days
    }

    private var groupedWeekItems: [(Date, [SonarrEpisode])] {
        var dict: [Date: [SonarrEpisode]] = [:]
        let cal = Calendar.current
        let start = trueWeekStart
        let end = weekEnd
        for episode in monthItems {
            guard let airDate = episode.airDate,
                  let date = Self.dateParser.date(from: airDate),
                  date >= start && date < end else { continue }
            dict[cal.startOfDay(for: date), default: []].append(episode)
        }
        return dict.sorted { $0.key < $1.key }
    }

    private var fetchKey: String { "\(displayedMonthStart.timeIntervalSince1970)-\(monitoredOnly)" }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CalendarMonthGridView(
                    monthStart: displayedMonthStart,
                    markedDays: markedDays,
                    selectedWeekStart: weekStart,
                    onWeekSelect: { weekStart = $0 },
                    onMonthShift: { shiftMonth($0) }
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 8)

                Divider()

                weekListSection
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { filterMenu }
            }
            .task(id: fetchKey) { await fetch() }
        }
    }

    @ViewBuilder
    private var weekListSection: some View {
        if isLoading {
            Spacer()
            ProgressView("Loading...")
            Spacer()
        } else if let error = errorMessage {
            ContentUnavailableView {
                Label("Error", systemImage: "wifi.exclamationmark")
            } description: {
                Text(error)
            }
        } else if groupedWeekItems.isEmpty {
            ContentUnavailableView(
                "No Episodes",
                systemImage: "calendar",
                description: Text("Nothing airing this week.")
            )
        } else {
            List {
                ForEach(groupedWeekItems, id: \.0) { day, episodes in
                    Section(Self.sectionFormatter.string(from: day)) {
                        ForEach(episodes) { episode in
                            SonarrCalendarRow(episode: episode, config: settings.config(for: .sonarr))
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private var filterMenu: some View {
        Menu {
            Toggle("Monitored Only", isOn: $monitoredOnly)
        } label: {
            Image(systemName: monitoredOnly ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel(monitoredOnly ? "Filter active" : "Filter")
    }

    private func shiftMonth(_ delta: Int) {
        guard let newMonth = Calendar.current.date(byAdding: .month, value: delta, to: displayedMonthStart) else { return }
        weekStart = newMonth
    }

    private func fetch() async {
        let cal = Calendar.current
        let mStart = displayedMonthStart
        let offset = (cal.component(.weekday, from: mStart) - cal.firstWeekday + 7) % 7
        let gridStart = cal.date(byAdding: .day, value: -offset, to: mStart)!
        let gridEnd = cal.date(byAdding: .day, value: 42, to: gridStart)!

        isLoading = true
        errorMessage = nil
        do {
            monthItems = try await ArrService.shared.fetchSonarrCalendar(
                settings.config(for: .sonarr),
                start: gridStart,
                end: gridEnd,
                unmonitored: !monitoredOnly
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct SonarrCalendarRow: View {
    let episode: SonarrEpisode
    let config: ServerConfig

    private var episodeCode: String {
        String(format: "S%02dE%02d", episode.seasonNumber, episode.episodeNumber)
    }

    private var seriesPosterURL: URL? {
        guard let path = episode.series?.posterImagePath else { return nil }
        return ImageURLResolver.resolve(path, baseURL: config.baseURL)
    }

    var body: some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: seriesPosterURL)
                .frame(width: 40, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                if let seriesTitle = episode.series?.title {
                    Text(seriesTitle)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                }
                HStack(spacing: 4) {
                    Text(episodeCode)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if let title = episode.title {
                        Text("· \(title)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                statusLabel
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel({
            var parts: [String] = []
            if let seriesTitle = episode.series?.title { parts.append(seriesTitle) }
            parts.append(episodeCode)
            if let title = episode.title { parts.append(title) }
            if episode.hasFile { parts.append("Downloaded") }
            else if !episode.monitored { parts.append("Unmonitored") }
            return parts.joined(separator: ", ")
        }())
    }

    @ViewBuilder
    private var statusLabel: some View {
        if episode.hasFile {
            Label("Downloaded", systemImage: "checkmark.circle.fill")
                .font(.caption2).foregroundStyle(.green)
        } else if !episode.monitored {
            Label("Unmonitored", systemImage: "bookmark.slash")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}
