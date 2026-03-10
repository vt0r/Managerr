import SwiftUI

struct TorrentDetailSheet: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss
    let torrent: TransmissionTorrent
    let viewModel: TransmissionViewModel

    @State private var showDeleteConfirmation: Bool = false

    private var detail: TransmissionTorrent {
        viewModel.detailedTorrent ?? torrent
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    progressHeader
                    transferSection
                    peersSection

                    if let trackers = detail.trackers, !trackers.isEmpty {
                        NavigationLink {
                            TrackerListView(
                                torrentId: torrent.id,
                                trackers: trackers,
                                trackerStats: detail.trackerStats ?? [],
                                viewModel: viewModel
                            )
                        } label: {
                            HStack {
                                Label("Trackers (\(trackers.count))", systemImage: "antenna.radiowaves.left.and.right")
                                    .foregroundStyle(.tint)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    if let files = detail.files, !files.isEmpty {
                        filesSection(files)
                    }

                    infoSection
                    actionButtons
                }
                .padding()
            }
            .navigationTitle(torrent.name ?? "Torrent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                let config = settings.config(for: .transmission)
                await viewModel.fetchTorrentDetail(config, id: torrent.id, showFlags: settings.showPeerFlags)
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(5))
                    guard !Task.isCancelled else { break }
                    await viewModel.fetchTorrentDetail(config, id: torrent.id, showFlags: settings.showPeerFlags)
                }
            }
            .confirmationDialog("Remove Torrent", isPresented: $showDeleteConfirmation) {
                Button("Remove Torrent", role: .destructive) {
                    Task {
                        await viewModel.removeTorrent(settings.config(for: .transmission), id: torrent.id, deleteData: false)
                        dismiss()
                    }
                }
                Button("Remove with Data", role: .destructive) {
                    Task {
                        await viewModel.removeTorrent(settings.config(for: .transmission), id: torrent.id, deleteData: true)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(detail.statusText, systemImage: detail.statusIcon)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(statusColor)
                Spacer()
                Text(FormatUtils.percentage(detail.percentDone))
                    .font(.subheadline.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: min(detail.percentDone ?? 0, 1.0), total: 1.0)
                .tint(statusColor)

            if let errorStr = detail.errorString, !errorStr.isEmpty, detail.error != 0 {
                Text(errorStr)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if detail.isActive {
                HStack(spacing: 20) {
                    if let dl = detail.rateDownload, dl > 0 {
                        Label(FormatUtils.speed(dl), systemImage: "arrow.down.circle.fill")
                            .foregroundStyle(.green)
                    }
                    if let ul = detail.rateUpload, ul > 0 {
                        Label(FormatUtils.speed(ul), systemImage: "arrow.up.circle.fill")
                            .foregroundStyle(.blue)
                    }
                    Spacer()
                    if let eta = detail.eta, eta > 0 {
                        Label(FormatUtils.eta(eta), systemImage: "clock")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline.monospacedDigit())
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Transfer Stats

    private var transferSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Transfer")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 14) {
                if let size = detail.totalSize {
                    statCell("Total Size", FormatUtils.fileSize(size))
                }
                if let downloaded = detail.downloadedEver {
                    statCell("Downloaded", FormatUtils.fileSize(downloaded))
                }
                if let uploaded = detail.uploadedEver {
                    statCell("Uploaded", FormatUtils.fileSize(uploaded))
                }
                if let ratio = detail.uploadRatio, ratio >= 0 {
                    statCell("Ratio", String(format: "%.2f", ratio))
                }
                if let left = detail.leftUntilDone, left > 0 {
                    statCell("Remaining", FormatUtils.fileSize(left))
                }
                if let selected = detail.sizeWhenDone, let total = detail.totalSize, selected != total {
                    statCell("Selected", FormatUtils.fileSize(selected))
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Peers

    private var peersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Peers")
                .font(.headline)

            if let connected = detail.peersConnected {
                HStack {
                    Label("\(connected) connected", systemImage: "person.2")
                    Spacer()
                    if let sending = detail.peersSendingToUs, let getting = detail.peersGettingFromUs {
                        Text("↓\(sending) · ↑\(getting)")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            if let peers = detail.peers, !peers.isEmpty {
                NavigationLink {
                    PeerListView(peers: peers, viewModel: viewModel)
                } label: {
                    HStack {
                        Label("View All Peers (\(peers.count))", systemImage: "person.2.circle")
                            .foregroundStyle(.tint)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Files

    private func filesSection(_ files: [TransmissionFile]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Files (\(files.count))")
                .font(.headline)

            ForEach(files) { file in
                VStack(alignment: .leading, spacing: 4) {
                    Text(fileName(file.name))
                        .font(.caption)
                        .lineLimit(2)

                    HStack {
                        if let length = file.length {
                            Text(FormatUtils.fileSize(length))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if let completed = file.bytesCompleted, let total = file.length, total > 0 {
                            Spacer()
                            ProgressView(value: Double(completed), total: Double(total))
                                .frame(width: 80)
                        }
                    }
                }
                .padding(.vertical, 2)

                if file.id != files.last?.id {
                    Divider()
                }
            }
        }
    }

    // MARK: - Info

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Info")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                if let dir = detail.downloadDir {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Location")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(dir)
                            .font(.caption)
                    }
                }

                if let hash = detail.hashString {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hash")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(hash)
                            .font(.system(.caption2, design: .monospaced))
                            .lineLimit(1)
                            .textSelection(.enabled)
                    }
                }

                let addedStr = detail.addedDate.flatMap { $0 > 0 ? formatDate($0) : nil }
                let doneStr = detail.doneDate.flatMap { $0 > 0 ? formatDate($0) : nil }

                if addedStr != nil || doneStr != nil {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 14) {
                        if let s = addedStr { statCell("Added", s) }
                        if let s = doneStr  { statCell("Completed", s) }
                    }
                }

                if let pieces = detail.pieceCount, let pieceSize = detail.pieceSize {
                    infoRow("Pieces", "\(pieces) × \(FormatUtils.fileSize(pieceSize))")
                }
                if let creator = detail.creator, !creator.isEmpty {
                    infoRow("Creator", creator)
                }
                if let comment = detail.comment, !comment.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Comment")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(comment)
                            .font(.caption)
                            .lineLimit(3)
                    }
                }
                if detail.isPrivate == true {
                    Label("Private Torrent", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                if torrent.status == 0 {
                    Button {
                        Task {
                            await viewModel.startTorrent(settings.config(for: .transmission), id: torrent.id)
                            dismiss()
                        }
                    } label: {
                        Label("Start", systemImage: "play.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                } else {
                    Button {
                        Task {
                            await viewModel.stopTorrent(settings.config(for: .transmission), id: torrent.id)
                            dismiss()
                        }
                    } label: {
                        Label("Stop", systemImage: "stop.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }

                Button {
                    Task {
                        await viewModel.verifyTorrent(settings.config(for: .transmission), id: torrent.id)
                        dismiss()
                    }
                } label: {
                    Label("Verify", systemImage: "checkmark.shield").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Remove Torrent", systemImage: "trash").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func statCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.medium))
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .font(.subheadline)
    }

    private var statusColor: Color {
        switch detail.status {
        case 0: return .orange
        case 1, 2: return .blue
        case 3, 4: return .green
        case 5, 6: return .purple
        default: return .secondary
        }
    }

    private func fileName(_ path: String?) -> String {
        guard let path else { return "Unknown" }
        return (path as NSString).lastPathComponent
    }

    private func formatDate(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
