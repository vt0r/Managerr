import SwiftUI

extension ServerConfig.ServiceType {
    var abbreviation: String {
        switch self {
        case .radarr: "R"
        case .sonarr: "S"
        case .lidarr: "L"
        case .transmission: "T"
        }
    }

    var badgeColor: Color {
        switch self {
        case .radarr: .blue
        case .sonarr: .teal
        case .lidarr: .green
        case .transmission: .orange
        }
    }
}

struct QueueView: View {
    @Environment(SettingsStore.self) private var settings
    @State private var viewModel: QueueViewModel
    @State private var selectedItem: ArrQueueItem?
    @State private var removingItem: ArrQueueItem?

    init(service: ServerConfig.ServiceType? = nil) {
        _viewModel = State(initialValue: QueueViewModel(limitToService: service))
    }

    private var anyConfigured: Bool {
        if let service = viewModel.limitToService {
            return settings.isConfigured(service)
        }
        return settings.isConfigured(.radarr) || settings.isConfigured(.sonarr) || settings.isConfigured(.lidarr)
    }

    var body: some View {
        NavigationStack {
            Group {
                if !anyConfigured {
                    notConfiguredView
                } else if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView("Loading activity queue...")
                } else if viewModel.filteredItems.isEmpty && viewModel.errorMessages.isEmpty {
                    emptyView
                } else {
                    itemList
                }
            }
            .navigationTitle("Activity")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    filterMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isLoading {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Button {
                            Task { await viewModel.fetch(settings) }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .refreshable { await viewModel.fetch(settings) }
            .task {
                while !Task.isCancelled {
                    await viewModel.fetch(settings)
                    try? await Task.sleep(for: .seconds(30))
                }
            }
            .sheet(item: $selectedItem) { item in
                QueueDetailSheet(item: item, viewModel: viewModel)
            }
        }
    }

    // MARK: - Filter menu

    private var filterMenu: some View {
        Menu {
            if viewModel.limitToService == nil {
                Picker("Service", selection: $viewModel.serviceFilter) {
                    Text("All Services").tag(Optional<ServerConfig.ServiceType>.none)
                    if settings.isConfigured(.radarr) {
                        Text("Radarr").tag(Optional<ServerConfig.ServiceType>.some(.radarr))
                    }
                    if settings.isConfigured(.sonarr) {
                        Text("Sonarr").tag(Optional<ServerConfig.ServiceType>.some(.sonarr))
                    }
                    if settings.isConfigured(.lidarr) {
                        Text("Lidarr").tag(Optional<ServerConfig.ServiceType>.some(.lidarr))
                    }
                }
                Divider()
            }

            Picker("Status", selection: $viewModel.statusFilter) {
                ForEach(QueueStatusFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
        } label: {
            Image(systemName: viewModel.isFiltered
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel("Filter")
    }

    // MARK: - Item list

    private var itemList: some View {
        List {
            ForEach(Array(viewModel.errorMessages.keys), id: \.self) { serviceType in
                if let msg = viewModel.errorMessages[serviceType] {
                    Label("\(serviceType.displayName): \(msg)", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .listRowBackground(Color(.secondarySystemBackground))
                }
            }

            ForEach(viewModel.filteredItems) { item in
                let isDelayed = item.record.status?.lowercased() == "delay"
                Button { selectedItem = item } label: {
                    QueueRowView(item: item)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        removingItem = item
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    if isDelayed {
                        Button {
                            Task { await viewModel.grabItem(settings, item: item) }
                        } label: {
                            Label("Force Grab", systemImage: "bolt.fill")
                        }
                        .tint(.green)
                    }
                }
                .contextMenu {
                    if isDelayed {
                        Button {
                            Task { await viewModel.grabItem(settings, item: item) }
                        } label: {
                            Label("Force Grab", systemImage: "bolt.fill")
                        }
                    }
                    Button(role: .destructive) {
                        removingItem = item
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .confirmationDialog(
            "Remove from Queue",
            isPresented: Binding(
                get: { removingItem != nil },
                set: { if !$0 { removingItem = nil } }
            ),
            presenting: removingItem
        ) { item in
            Button("Remove", role: .destructive) {
                Task { await viewModel.removeItem(settings, item: item, blacklist: false) }
                removingItem = nil
            }
            Button("Remove & Blocklist", role: .destructive) {
                Task { await viewModel.removeItem(settings, item: item, blacklist: true) }
                removingItem = nil
            }
            Button("Cancel", role: .cancel) { removingItem = nil }
        } message: { item in
            Text("Remove \"\(item.record.displayTitle)\" from the download queue?")
        }
    }

    // MARK: - Empty / unconfigured

    private var emptyView: some View {
        ContentUnavailableView {
            Label(
                viewModel.isFiltered ? "No Matching Items" : "Queue is Empty",
                systemImage: viewModel.isFiltered ? "line.3.horizontal.decrease.circle" : "checkmark.circle"
            )
        } description: {
            Text(viewModel.isFiltered
                 ? "Try adjusting the filter."
                 : "No active downloads across your configured services.")
        }
    }

    private var notConfiguredView: some View {
        ContentUnavailableView {
            Label("Not Configured", systemImage: "gearshape.2")
        } description: {
            if let service = viewModel.limitToService {
                Text("Configure \(service.displayName) in Settings to view its activity queue.")
            } else {
                Text("Configure Radarr, Sonarr, or Lidarr in Settings to view their activity queues.")
            }
        }
    }
}

// MARK: - Row

private struct QueueRowView: View {
    let item: ArrQueueItem

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                serviceBadge
                Text(item.record.displayTitle)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Spacer()
                statusLabel
            }

            if let releaseTitle = item.record.title, releaseTitle != item.record.displayTitle {
                Text(releaseTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            ProgressView(value: item.record.progressFraction)
                .tint(progressColor)

            HStack {
                sizeLabel
                Spacer()
                progressLabel
            }

            if item.record.hasError || item.record.hasWarning {
                errorPreview
            }
        }
        .padding(.vertical, 4)
    }

    private var serviceBadge: some View {
        Text(item.serviceType.abbreviation)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(item.serviceType.badgeColor, in: RoundedRectangle(cornerRadius: 4))
    }

    private var statusLabel: some View {
        Text(formattedStatus)
            .font(.caption2.weight(.medium))
            .foregroundStyle(statusColor)
    }

    @ViewBuilder
    private var sizeLabel: some View {
        if let size = item.record.size, size > 0 {
            let downloaded = size - (item.record.sizeleft ?? size)
            Text("\(FormatUtils.fileSize(Int64(max(0, downloaded)))) / \(FormatUtils.fileSize(Int64(size)))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var progressLabel: some View {
        HStack(spacing: 4) {
            Text(String(format: "%.1f%%", item.record.progressFraction * 100))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            if let timeleft = item.record.timeleft,
               let formatted = formatTimeLeft(timeleft) {
                Text("·").foregroundStyle(.secondary)
                Text(formatted)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var errorPreview: some View {
        let icon = item.record.hasError ? "xmark.circle.fill" : "exclamationmark.triangle.fill"
        let color: Color = item.record.hasError ? .red : .orange
        if let messages = item.record.statusMessages,
           let first = messages.first,
           let msgs = first.messages,
           let firstMsg = msgs.first {
            HStack(spacing: 4) {
                Image(systemName: icon).foregroundStyle(color)
                Text(firstMsg).lineLimit(1)
                if (messages.reduce(0) { $0 + ($1.messages?.count ?? 0) }) > 1 {
                    Text("· more").foregroundStyle(color.opacity(0.7))
                }
            }
            .font(.caption2)
            .foregroundStyle(color)
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
        case "queued": return .secondary
        case "paused": return .orange
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
}
