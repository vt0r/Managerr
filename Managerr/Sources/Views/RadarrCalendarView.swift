import SwiftUI

struct RadarrCalendarView: View {
    @Environment(SettingsStore.self) private var settings
    @State private var weekStart: Date = Self.currentWeekStart()
    @State private var monthItems: [RadarrMovie] = []
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
        for movie in monthItems {
            if let date = calendarDate(for: movie) {
                days.insert(Calendar.current.startOfDay(for: date))
            }
        }
        return days
    }

    private var groupedWeekItems: [(Date, [RadarrMovie])] {
        var dict: [Date: [RadarrMovie]] = [:]
        let cal = Calendar.current
        let start = trueWeekStart
        let end = weekEnd
        for movie in monthItems {
            if let date = calendarDate(for: movie), date >= start && date < end {
                dict[cal.startOfDay(for: date), default: []].append(movie)
            }
        }
        return dict.sorted { $0.key < $1.key }
    }

    private func calendarDate(for movie: RadarrMovie) -> Date? {
        [movie.inCinemas, movie.digitalRelease, movie.physicalRelease]
            .compactMap { $0.flatMap { Self.dateParser.date(from: String($0.prefix(10))) } }
            .min()
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
                "No Releases",
                systemImage: "calendar",
                description: Text("Nothing scheduled this week.")
            )
        } else {
            List {
                ForEach(groupedWeekItems, id: \.0) { day, movies in
                    Section(Self.sectionFormatter.string(from: day)) {
                        ForEach(movies) { movie in
                            RadarrCalendarRow(movie: movie, config: settings.config(for: .radarr))
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
        weekStart = newMonth  // 1st of new month; displayedMonthStart derives correctly from this
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
            monthItems = try await ArrService.shared.fetchRadarrCalendar(
                settings.config(for: .radarr),
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

struct RadarrCalendarRow: View {
    let movie: RadarrMovie
    let config: ServerConfig

    var body: some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: movie.posterURL(baseURL: config.baseURL))
                .frame(width: 40, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                releaseTypeBadges
                statusLabel
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel({
            var parts = [movie.title]
            if movie.inCinemas != nil { parts.append("In Cinemas") }
            if movie.digitalRelease != nil { parts.append("Digital") }
            if movie.physicalRelease != nil { parts.append("Physical") }
            if movie.hasFile { parts.append("Downloaded") }
            else if !movie.monitored { parts.append("Unmonitored") }
            return parts.joined(separator: ", ")
        }())
    }

    private var releaseTypeBadges: some View {
        HStack(spacing: 4) {
            if movie.inCinemas != nil { calendarBadge("In Cinemas", color: .blue) }
            if movie.digitalRelease != nil { calendarBadge("Digital", color: .purple) }
            if movie.physicalRelease != nil { calendarBadge("Physical", color: .orange) }
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        if movie.hasFile {
            Label("Downloaded", systemImage: "checkmark.circle.fill")
                .font(.caption2).foregroundStyle(.green)
        } else if !movie.monitored {
            Label("Unmonitored", systemImage: "bookmark.slash")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func calendarBadge(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
