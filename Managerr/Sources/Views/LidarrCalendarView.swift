import SwiftUI

struct LidarrCalendarView: View {
    @Environment(SettingsStore.self) private var settings
    @State private var weekStart: Date = Self.currentWeekStart()
    @State private var monthItems: [LidarrAlbum] = []
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
        for album in monthItems {
            if let releaseDate = album.releaseDate,
               let date = Self.dateParser.date(from: String(releaseDate.prefix(10))) {
                days.insert(Calendar.current.startOfDay(for: date))
            }
        }
        return days
    }

    private var groupedWeekItems: [(Date, [LidarrAlbum])] {
        var dict: [Date: [LidarrAlbum]] = [:]
        let cal = Calendar.current
        let start = trueWeekStart
        let end = weekEnd
        for album in monthItems {
            guard let releaseDate = album.releaseDate,
                  let date = Self.dateParser.date(from: String(releaseDate.prefix(10))),
                  date >= start && date < end else { continue }
            dict[cal.startOfDay(for: date), default: []].append(album)
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
                "No Releases",
                systemImage: "calendar",
                description: Text("Nothing releasing this week.")
            )
        } else {
            List {
                ForEach(groupedWeekItems, id: \.0) { day, albums in
                    Section(Self.sectionFormatter.string(from: day)) {
                        ForEach(albums) { album in
                            LidarrCalendarRow(album: album, config: settings.config(for: .lidarr))
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
            monthItems = try await ArrService.shared.fetchLidarrCalendar(
                settings.config(for: .lidarr),
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

struct LidarrCalendarRow: View {
    let album: LidarrAlbum
    let config: ServerConfig

    var body: some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: album.coverURL(config: config))
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(album.title ?? "Unknown Album")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                if let artistName = album.artist?.artistName {
                    Text(artistName)
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                HStack(spacing: 6) {
                    if let albumType = album.albumType {
                        Text(albumType)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.12))
                            .foregroundStyle(.tint)
                            .clipShape(Capsule())
                    }
                    statusLabel
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var statusLabel: some View {
        if (album.statistics?.trackFileCount ?? 0) > 0 {
            Label("Downloaded", systemImage: "checkmark.circle.fill")
                .font(.caption2).foregroundStyle(.green)
        } else if !album.monitored {
            Label("Unmonitored", systemImage: "bookmark.slash")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}
