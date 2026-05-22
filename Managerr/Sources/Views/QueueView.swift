import SwiftUI


struct QueueView: View {
    @Environment(SettingsStore.self) private var settings
    @State private var viewModel: QueueViewModel
    @State private var selectedItem: ArrQueueItem?
    @State private var removingItem: ArrQueueItem?

    init(service: ServerConfig.ServiceType) {
        _viewModel = State(initialValue: QueueViewModel(service: service))
    }

    var body: some View {
        NavigationStack {
            Group {
                if !settings.isConfigured(viewModel.service) {
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
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(viewModel.errorMessages.keys), id: \.self) { serviceType in
                    if let msg = viewModel.errorMessages[serviceType] {
                        Label("\(serviceType.displayName): \(msg)", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                }

                ForEach(viewModel.filteredItems) { item in
                    let isDelayed = item.record.status?.lowercased() == "delay"
                    Button { selectedItem = item } label: {
                        QueueRowView(item: item)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
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
            .padding(.horizontal)
            .padding(.bottom, 88)
        }
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
                 : "No active downloads in \(viewModel.service.displayName).")
        }
    }

    private var notConfiguredView: some View {
        ContentUnavailableView {
            Label("Not Configured", systemImage: "gearshape.2")
        } description: {
            Text("Configure \(viewModel.service.displayName) in Settings to view its activity queue.")
        }
    }
}

// MARK: - Row

private struct QueueRowView: View {
    let item: ArrQueueItem

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Image(systemName: statusIcon)
                    .font(.caption)
                    .foregroundStyle(statusColor)
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

    private var statusIcon: String {
        if item.record.hasError { return "xmark.circle.fill" }
        if item.record.hasWarning { return "exclamationmark.triangle.fill" }
        switch item.record.status?.lowercased() {
        case "downloading":                     return "arrow.down.circle.fill"
        case "queued":                          return "clock"
        case "paused":                          return "pause.circle.fill"
        case "completed":                       return "checkmark.circle.fill"
        case "importpending", "importing":      return "tray.and.arrow.down.fill"
        case "failed", "failedpending":         return "xmark.circle.fill"
        case "delay":                           return "exclamationmark.clock"
        case "downloadclientunavailable":       return "arrow.down.circle.badge.xmark.fill"
        default:                                return "questionmark.circle"
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
