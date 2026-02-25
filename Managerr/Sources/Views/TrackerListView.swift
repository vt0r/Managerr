import SwiftUI

struct TrackerListView: View {
    @Environment(SettingsStore.self) private var settings
    let torrentId: Int
    let trackers: [TransmissionTracker]
    let trackerStats: [TransmissionTrackerStats]
    let viewModel: TransmissionViewModel

    var body: some View {
        List {
            ForEach(groupedTrackers, id: \.tier) { group in
                Section("Tier \(group.tier)") {
                    ForEach(group.items) { item in
                        TrackerRow(tracker: item.tracker, stats: item.stats)
                    }
                }
            }

            Section {
                Button {
                    Task {
                        await viewModel.reannounceTorrent(settings.config(for: .transmission), id: torrentId)
                    }
                } label: {
                    Label("Reannounce", systemImage: "arrow.triangle.2.circlepath")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Trackers")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var groupedTrackers: [TrackerGroup] {
        var groups: [Int: [TrackerItem]] = [:]
        for tracker in trackers {
            let tier = tracker.tier ?? 0
            let stats = trackerStats.first { $0.id == tracker.id }
            let item = TrackerItem(tracker: tracker, stats: stats)
            groups[tier, default: []].append(item)
        }
        return groups.keys.sorted().map { TrackerGroup(tier: $0, items: groups[$0] ?? []) }
    }
}

private struct TrackerGroup {
    let tier: Int
    let items: [TrackerItem]
}

private struct TrackerItem: Identifiable {
    let tracker: TransmissionTracker
    let stats: TransmissionTrackerStats?
    var id: Int { tracker.id }
}

struct TrackerRow: View {
    let tracker: TransmissionTracker
    let stats: TransmissionTrackerStats?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(stats?.host ?? trackerHost)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)

            if let stats {
                HStack(spacing: 16) {
                    if let seeders = stats.seederCount, seeders >= 0 {
                        Label("\(seeders)", systemImage: "arrow.up")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                    if let leechers = stats.leecherCount, leechers >= 0 {
                        Label("\(leechers)", systemImage: "arrow.down")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                    if let peerCount = stats.lastAnnouncePeerCount, peerCount >= 0 {
                        Label("\(peerCount) peers", systemImage: "person.2")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Circle()
                        .fill(announceStateColor)
                        .frame(width: 6, height: 6)

                    Text(stats.lastAnnounceResult ?? "No response")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    if let time = stats.lastAnnounceTime, time > 0 {
                        Text(lastAnnounceDate(time))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var trackerHost: String {
        guard let announce = tracker.announce,
              let url = URL(string: announce) else { return "Unknown" }
        return url.host ?? announce
    }

    private var announceStateColor: Color {
        guard let succeeded = stats?.lastAnnounceSucceeded else { return Color(.tertiaryLabel) }
        return succeeded ? .green : .red
    }

    private func lastAnnounceDate(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
