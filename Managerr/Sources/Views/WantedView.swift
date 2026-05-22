import SwiftUI

struct WantedView: View {
    @Environment(SettingsStore.self) private var settings
    @State private var viewModel: WantedViewModel
    @State private var selectedItem: WantedItem?

    init(service: ServerConfig.ServiceType) {
        _viewModel = State(initialValue: WantedViewModel(service: service))
    }

    var body: some View {
        NavigationStack {
            Group {
                if !settings.isConfigured(viewModel.service) {
                    notConfiguredView
                } else if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.items.isEmpty && viewModel.errorMessages.isEmpty {
                    emptyView
                } else {
                    itemList
                }
            }
            .navigationTitle("Wanted")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    filterMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            Task { await viewModel.fetch(settings) }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Actions")
                }
            }
            .refreshable { await viewModel.fetch(settings) }
            .task { await viewModel.fetch(settings) }
            .onChange(of: viewModel.filter) { _, _ in
                Task { await viewModel.fetch(settings) }
            }
            .sheet(item: $selectedItem) { item in
                WantedDetailSheet(item: item, filter: viewModel.filter, viewModel: viewModel)
            }
        }
    }

    // MARK: - Filter Menu

    private var filterMenu: some View {
        Menu {
            Picker("Filter", selection: $viewModel.filter) {
                ForEach(WantedFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
        } label: {
            Image(systemName: viewModel.filter == .missing
                  ? "line.3.horizontal.decrease.circle"
                  : "line.3.horizontal.decrease.circle.fill")
        }
        .accessibilityLabel("Filter")
    }

    // MARK: - Item List

    private var itemList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(viewModel.errorMessages.keys), id: \.self) { service in
                    if let msg = viewModel.errorMessages[service] {
                        Label("\(service.displayName): \(msg)", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                }

                ForEach(viewModel.items) { item in
                    Button { selectedItem = item } label: {
                        WantedRowView(item: item, filter: viewModel.filter)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.primaryTitle)
                    .accessibilityValue({
                        var parts: [String] = []
                        if let secondary = item.secondaryTitle { parts.append(secondary) }
                        if viewModel.filter == .missing {
                            parts.append(item.isAvailable ? "Available, missing" : "Not yet released")
                        } else {
                            parts.append("Cutoff unmet")
                            if let quality = item.qualityLabel { parts.append(quality) }
                        }
                        return parts.joined(separator: ", ")
                    }())
                    .contextMenu {
                        Button {
                            Task { await viewModel.autoSearch(settings, item: item) }
                        } label: {
                            Label("Auto Search", systemImage: "magnifyingglass")
                        }
                        Button { selectedItem = item } label: {
                            Label("Manual Search", systemImage: "list.bullet.rectangle")
                        }
                        Divider()
                        Button(role: .destructive) {
                            Task { await viewModel.unmonitor(settings, item: item) }
                        } label: {
                            Label("Unmonitor", systemImage: "bookmark.slash")
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 88)
        }
    }

    // MARK: - Empty / Not Configured

    private var emptyView: some View {
        ContentUnavailableView {
            Label("Nothing \(viewModel.filter.rawValue)", systemImage: "checkmark.circle")
        } description: {
            Text(viewModel.filter == .missing
                 ? "All monitored media has been downloaded."
                 : "All monitored media meets the quality cutoff.")
        }
    }

    private var notConfiguredView: some View {
        ContentUnavailableView {
            Label("Not Configured", systemImage: "gearshape.2")
        } description: {
            Text("Configure \(viewModel.service.displayName) in Settings to view its wanted list.")
        }
    }
}

// MARK: - Row

private struct WantedRowView: View {
    let item: WantedItem
    let filter: WantedFilter

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.primaryTitle)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)

                if let secondary = item.secondaryTitle {
                    Text(secondary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let detail = item.detailText {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 8)
            statusIndicator
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch filter {
        case .missing:
            Image(systemName: item.isAvailable ? "exclamationmark.triangle.fill" : "calendar.badge.clock")
                .font(.subheadline)
                .foregroundStyle(item.isAvailable ? .orange : .secondary)
        case .cutoffUnmet:
            if let quality = item.qualityLabel {
                Text(quality)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(.tertiarySystemBackground), in: Capsule())
            } else {
                Image(systemName: "arrow.up.circle")
                    .font(.subheadline)
                    .foregroundStyle(.tint)
            }
        }
    }
}
