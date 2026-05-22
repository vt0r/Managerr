import SwiftUI

struct QueueDetailSheet: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss
    let item: ArrQueueItem
    let viewModel: QueueViewModel

    @State private var showRemoveConfirm = false

    private var isDelayed: Bool { item.record.status?.lowercased() == "delay" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    VStack(alignment: .leading, spacing: 20) {
                        progressSection
                        Divider()
                        downloadDetailsSection
                        if item.record.hasError || item.record.hasWarning {
                            statusMessagesSection
                        }
                        actionsSection
                    }
                    .padding()
                }
            }
            .navigationTitle(item.record.displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Remove from Queue", isPresented: $showRemoveConfirm) {
                Button("Remove", role: .destructive) {
                    Task {
                        await viewModel.removeItem(settings, item: item, blacklist: false)
                        dismiss()
                    }
                }
                Button("Remove & Blocklist", role: .destructive) {
                    Task {
                        await viewModel.removeItem(settings, item: item, blacklist: true)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Remove \"\(item.record.displayTitle)\" from the download queue?")
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        ZStack(alignment: .bottomLeading) {
            item.serviceType.badgeColor.opacity(0.12)
                .frame(maxWidth: .infinity)
                .frame(height: 90)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(item.serviceType.abbreviation)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(item.serviceType.badgeColor, in: RoundedRectangle(cornerRadius: 5))
                    Text(serviceLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formattedStatus)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor)
                }
                Text(item.record.displayTitle)
                    .font(.title3.bold())
                    .lineLimit(2)
            }
            .padding()
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Progress")
                .font(.headline)

            ProgressView(value: item.record.progressFraction)
                .tint(progressColor)

            HStack {
                if let size = item.record.size, size > 0 {
                    let dl = size - (item.record.sizeleft ?? size)
                    Text("\(FormatUtils.fileSize(Int64(max(0, dl)))) of \(FormatUtils.fileSize(Int64(size)))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(String(format: "%.1f%%", item.record.progressFraction * 100))
                    .font(.subheadline.weight(.medium).monospacedDigit())
            }

            if let timeleft = item.record.timeleft, let formatted = formatTimeLeft(timeleft) {
                Label("\(formatted) remaining", systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let eta = item.record.estimatedCompletionTime,
               let date = parseDate(eta) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar.clock")
                    Text("Completes")
                    Text(date, style: .relative)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Download details

    private var downloadDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Download")
                .font(.headline)

            if let proto = item.record.downloadProtocol, !proto.isEmpty {
                detailRow(label: "Protocol", value: proto.capitalized, icon: protoIcon(proto))
            }
            if let client = item.record.downloadClient, !client.isEmpty {
                detailRow(label: "Client", value: client, icon: "arrow.down.circle")
            }
            if let indexer = item.record.indexer, !indexer.isEmpty {
                detailRow(label: "Indexer", value: indexer, icon: "magnifyingglass")
            }
            if let title = item.record.title, !title.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Release", systemImage: "doc.text")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(title)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }
        }
    }

    // MARK: - Status messages

    @ViewBuilder
    private var statusMessagesSection: some View {
        if let messages = item.record.statusMessages, !messages.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                let isError = item.record.hasError
                Label(
                    "Status Messages",
                    systemImage: isError ? "xmark.circle.fill" : "exclamationmark.triangle.fill"
                )
                .font(.headline)
                .foregroundStyle(isError ? .red : .orange)

                VStack(spacing: 0) {
                    ForEach(messages.indices, id: \.self) { i in
                        let group = messages[i]
                        if let msgs = group.messages, !msgs.isEmpty {
                            if let title = group.title, !title.isEmpty {
                                Text(title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.top, 10)
                                    .padding(.bottom, 2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            ForEach(msgs, id: \.self) { msg in
                                Text(msg)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                                if msg != msgs.last {
                                    Divider().padding(.leading, 12)
                                }
                            }
                        }
                    }
                }
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 10) {
            if isDelayed {
                Button {
                    Task {
                        await viewModel.grabItem(settings, item: item)
                        dismiss()
                    }
                } label: {
                    Label("Force Grab", systemImage: "bolt.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            Button(role: .destructive) {
                showRemoveConfirm = true
            } label: {
                Label("Remove from Queue", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private var serviceLabel: String {
        switch item.serviceType {
        case .radarr: "Movie"
        case .sonarr: item.record.episode != nil ? "Episode" : "Series"
        case .lidarr: "Album"
        case .transmission: ""
        }
    }

    private var formattedStatus: String {
        switch item.record.status?.lowercased() {
        case "downloading": return "Downloading"
        case "queued": return "Queued"
        case "paused": return "Paused"
        case "completed": return "Completed"
        case "failed", "failedpending": return "Failed"
        case "importpending", "importing": return "Importing"
        case "delay": return "Delayed"
        case "downloadclientunavailable": return "No Client"
        default: return item.record.status?.capitalized ?? "Unknown"
        }
    }

    private var statusColor: Color {
        if item.record.hasError { return .red }
        if item.record.hasWarning { return .orange }
        switch item.record.status?.lowercased() {
        case "downloading": return .blue
        case "completed": return .green
        case "failed", "failedpending": return .red
        case "importpending", "importing": return .teal
        case "delay": return .yellow
        default: return .secondary
        }
    }

    private var progressColor: Color {
        if item.record.hasError { return .red }
        if item.record.hasWarning { return .orange }
        switch item.record.status?.lowercased() {
        case "completed", "importing", "importpending": return .green
        case "paused": return .orange
        default: return .accentColor
        }
    }

    private func detailRow(label: String, value: String, icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            Text(value)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    private func protoIcon(_ proto: String) -> String {
        switch proto.lowercased() {
        case "torrent": return "arrow.triangle.2.circlepath"
        case "usenet": return "newspaper"
        default: return "network"
        }
    }

    private func formatTimeLeft(_ timeleft: String) -> String? {
        let parts = timeleft.split(separator: ":")
        guard parts.count == 3 else { return nil }
        var totalHours = 0
        let hourPart = String(parts[0])
        if hourPart.contains(".") {
            let dayHour = hourPart.split(separator: ".")
            let days = Int(dayHour[0]) ?? 0
            let hours = Int(dayHour[1]) ?? 0
            totalHours = days * 24 + hours
        } else {
            totalHours = Int(hourPart) ?? 0
        }
        let minutes = Int(parts[1]) ?? 0
        let seconds = Int(parts[2]) ?? 0
        if totalHours > 0 { return "\(totalHours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m" }
        if seconds > 0 { return "\(seconds)s" }
        return nil
    }

    private func parseDate(_ iso: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: iso) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: iso)
    }
}
