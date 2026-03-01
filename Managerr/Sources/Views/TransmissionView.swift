import SwiftUI
import UniformTypeIdentifiers

struct TransmissionView: View {
    @Environment(SettingsStore.self) private var settings
    @State private var viewModel = TransmissionViewModel()
    @State private var showFilePicker: Bool = false
    @State private var showMagnetAlert: Bool = false
    @State private var showURLAlert: Bool = false
    @State private var magnetLink: String = ""
    @State private var torrentURLString: String = ""
    @State private var selectedTorrent: TransmissionTorrent?

    var body: some View {
        NavigationStack {
            Group {
                if !settings.isConfigured(.transmission) {
                    notConfiguredView
                } else if viewModel.isLoading && viewModel.torrents.isEmpty {
                    ProgressView("Loading torrents...")
                } else if let error = viewModel.errorMessage, viewModel.torrents.isEmpty {
                    errorView(error)
                } else {
                    torrentList
                }
            }
            .navigationTitle("Downloads")
            .searchable(text: $viewModel.searchText, prompt: "Search torrents")
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Filter", selection: $viewModel.filterStatus) {
                            ForEach(TransmissionViewModel.FilterStatus.allCases, id: \.self) { status in
                                Text(status.rawValue).tag(status)
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("Filter")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            Task { await viewModel.startAll(settings.config(for: .transmission)) }
                        } label: {
                            Label("Start All", systemImage: "play.fill")
                        }
                        Button {
                            Task { await viewModel.stopAll(settings.config(for: .transmission)) }
                        } label: {
                            Label("Stop All", systemImage: "stop.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Actions")
                }
            }
            .refreshable {
                await viewModel.fetchTorrents(settings.config(for: .transmission))
            }
            .task {
                guard settings.isConfigured(.transmission) else { return }
                let config = settings.config(for: .transmission)
                if viewModel.torrents.isEmpty {
                    await viewModel.fetchTorrents(config)
                } else {
                    await viewModel.fetchTorrentsSilently(config)
                }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(5))
                    guard !Task.isCancelled else { break }
                    await viewModel.fetchTorrentsSilently(config)
                }
            }
            .alert("Add Magnet Link", isPresented: $showMagnetAlert) {
                TextField("magnet:?xt=urn:btih:…", text: $magnetLink)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Add") {
                    let link = magnetLink
                    magnetLink = ""
                    guard !link.isEmpty else { return }
                    Task { await viewModel.addTorrent(settings.config(for: .transmission), url: link) }
                }
                Button("Cancel", role: .cancel) { magnetLink = "" }
            } message: {
                Text("Paste a magnet link to add the torrent.")
            }
            .alert("Add Torrent URL", isPresented: $showURLAlert) {
                TextField("https://example.com/file.torrent", text: $torrentURLString)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Add") {
                    let url = torrentURLString
                    torrentURLString = ""
                    guard !url.isEmpty else { return }
                    Task { await viewModel.addTorrent(settings.config(for: .transmission), url: url) }
                }
                Button("Cancel", role: .cancel) { torrentURLString = "" }
            } message: {
                Text("Paste a direct URL to a .torrent file.")
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [UTType(mimeType: "application/x-bittorrent") ?? .data]
            ) { result in
                guard case .success(let url) = result else { return }
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                guard let data = try? Data(contentsOf: url) else { return }
                Task { await viewModel.addTorrentFile(settings.config(for: .transmission), data: data) }
            }
            .sheet(item: $selectedTorrent) { torrent in
                TorrentDetailSheet(torrent: torrent, viewModel: viewModel)
            }
            .overlay(alignment: .bottomTrailing) {
                if settings.isConfigured(.transmission) &&
                   !(viewModel.isLoading && viewModel.torrents.isEmpty) &&
                   !(viewModel.errorMessage != nil && viewModel.torrents.isEmpty) {
                    Menu {
                        Button {
                            showFilePicker = true
                        } label: {
                            Label("Upload .torrent File", systemImage: "doc.badge.plus")
                        }
                        Button {
                            showMagnetAlert = true
                        } label: {
                            Label("Add Magnet Link", systemImage: "link")
                        }
                        Button {
                            showURLAlert = true
                        } label: {
                            Label("Add Torrent URL", systemImage: "globe")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(.tint)
                            .clipShape(.circle)
                            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                    }
                    .accessibilityLabel("Add Torrent")
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    private var torrentList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if viewModel.totalDownloadSpeed > 0 || viewModel.totalUploadSpeed > 0 {
                    HStack(spacing: 16) {
                        Label(FormatUtils.speed(viewModel.totalDownloadSpeed), systemImage: "arrow.down")
                            .foregroundStyle(.blue)
                        Spacer()
                        Label(FormatUtils.speed(viewModel.totalUploadSpeed), systemImage: "arrow.up")
                            .foregroundStyle(.green)
                    }
                    .font(.subheadline.weight(.medium))
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }

                if viewModel.filteredTorrents.isEmpty {
                    ContentUnavailableView("No Torrents", systemImage: "arrow.down.circle")
                } else {
                    ForEach(viewModel.filteredTorrents) { torrent in
                        torrentCell(torrent)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 88)
        }
    }

    @ViewBuilder
    private func torrentCell(_ torrent: TransmissionTorrent) -> some View {
        let config = settings.config(for: .transmission)
        Button { selectedTorrent = torrent } label: {
            TorrentRow(torrent: torrent, onToggle: {
                Task {
                    if torrent.status == 0 {
                        await viewModel.startTorrent(config, id: torrent.id)
                    } else {
                        await viewModel.stopTorrent(config, id: torrent.id)
                    }
                }
            })
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if torrent.status == 0 {
                Button {
                    Task { await viewModel.startTorrent(config, id: torrent.id) }
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
            } else {
                Button {
                    Task { await viewModel.stopTorrent(config, id: torrent.id) }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
            }
            Divider()
            Button(role: .destructive) {
                Task { await viewModel.removeTorrent(config, id: torrent.id, deleteData: false) }
            } label: {
                Label("Remove", systemImage: "trash")
            }
            Button(role: .destructive) {
                Task { await viewModel.removeTorrent(config, id: torrent.id, deleteData: true) }
            } label: {
                Label("Remove with Data", systemImage: "trash.fill")
            }
        }
        .accessibilityLabel(torrent.name ?? "Unknown torrent")
        .accessibilityValue(torrent.statusText)
        .accessibilityAction(named: "Remove") {
            Task { await viewModel.removeTorrent(config, id: torrent.id, deleteData: false) }
        }
        .accessibilityAction(named: torrent.status == 0 ? "Start" : "Stop") {
            Task {
                if torrent.status == 0 {
                    await viewModel.startTorrent(config, id: torrent.id)
                } else {
                    await viewModel.stopTorrent(config, id: torrent.id)
                }
            }
        }
    }

    private var notConfiguredView: some View {
        ContentUnavailableView {
            Label("Transmission Not Configured", systemImage: "arrow.down.circle")
        } description: {
            Text("Add your Transmission server URL in Settings to get started.")
        }
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Connection Error", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Retry") {
                Task { await viewModel.fetchTorrents(settings.config(for: .transmission)) }
            }
            .buttonStyle(.bordered)
        }
    }
}

struct TorrentRow: View {
    let torrent: TransmissionTorrent
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: torrent.statusIcon)
                    .font(.caption)
                    .foregroundStyle(statusColor)

                Text(torrent.name ?? "Unknown")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                ProgressView(value: torrent.percentDone ?? 0)
                    .tint(statusColor)

                Button {
                    onToggle()
                } label: {
                    Image(systemName: torrent.status == 0 ? "play.circle.fill" : "pause.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .accessibilityLabel(torrent.status == 0 ? "Start" : "Pause")
            }

            HStack {
                Text(torrent.statusText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(FormatUtils.percentage(torrent.percentDone))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)

                if let size = torrent.totalSize, size > 0 {
                    Text("· \(FormatUtils.fileSize(size))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if torrent.isActive {
                HStack(spacing: 12) {
                    if let dl = torrent.rateDownload, dl > 0 {
                        Label(FormatUtils.speed(dl), systemImage: "arrow.down")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                    if let ul = torrent.rateUpload, ul > 0 {
                        Label(FormatUtils.speed(ul), systemImage: "arrow.up")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                    if let eta = torrent.eta, eta > 0 {
                        Label(FormatUtils.eta(eta), systemImage: "clock")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            let hasDl = (torrent.downloadedEver ?? 0) > 0
            let hasUl = (torrent.uploadedEver ?? 0) > 0
            let hasRatio = (torrent.uploadRatio ?? -1) >= 0
            if hasDl || hasUl || hasRatio {
                HStack(spacing: 12) {
                    if hasDl {
                        Label(FormatUtils.fileSize(torrent.downloadedEver!), systemImage: "arrow.down.circle")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if hasUl {
                        Label(FormatUtils.fileSize(torrent.uploadedEver!), systemImage: "arrow.up.circle")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if hasRatio {
                        Label(String(format: "%.2f", torrent.uploadRatio!), systemImage: "arrow.left.arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var statusColor: Color {
        switch torrent.status {
        case 4: .blue
        case 6: .green
        case 0: Color(.tertiaryLabel)
        default: .orange
        }
    }
}
