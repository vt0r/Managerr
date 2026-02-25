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
            List {
                Section("Status") {
                    row("Status", value: detail.statusText)
                    row("Progress", value: FormatUtils.percentage(detail.percentDone))

                    if detail.isActive {
                        if let dl = detail.rateDownload {
                            row("Download Speed", value: FormatUtils.speed(dl))
                        }
                        if let ul = detail.rateUpload {
                            row("Upload Speed", value: FormatUtils.speed(ul))
                        }
                        if let eta = detail.eta, eta > 0 {
                            row("ETA", value: FormatUtils.eta(eta))
                        }
                    }

                    if let errorStr = detail.errorString, !errorStr.isEmpty, detail.error != 0 {
                        HStack {
                            Text("Error")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(errorStr)
                                .fontWeight(.medium)
                                .foregroundStyle(.red)
                                .lineLimit(2)
                                .multilineTextAlignment(.trailing)
                        }
                        .font(.subheadline)
                    }
                }

                Section("Transfer") {
                    if let size = detail.totalSize {
                        row("Total Size", value: FormatUtils.fileSize(size))
                    }
                    if let sizeWhenDone = detail.sizeWhenDone, sizeWhenDone > 0 {
                        row("Selected Size", value: FormatUtils.fileSize(sizeWhenDone))
                    }
                    if let downloaded = detail.downloadedEver {
                        row("Downloaded", value: FormatUtils.fileSize(downloaded))
                    }
                    if let uploaded = detail.uploadedEver {
                        row("Uploaded", value: FormatUtils.fileSize(uploaded))
                    }
                    if let ratio = detail.uploadRatio, ratio >= 0 {
                        row("Ratio", value: String(format: "%.2f", ratio))
                    }
                    if let left = detail.leftUntilDone, left > 0 {
                        row("Remaining", value: FormatUtils.fileSize(left))
                    }
                }

                Section("Peers") {
                    if let connected = detail.peersConnected {
                        row("Connected", value: "\(connected)")
                    }
                    if let sending = detail.peersSendingToUs {
                        row("Sending to us", value: "\(sending)")
                    }
                    if let getting = detail.peersGettingFromUs {
                        row("Getting from us", value: "\(getting)")
                    }

                    if let peers = detail.peers, !peers.isEmpty {
                        NavigationLink {
                            PeerListView(
                                peers: peers,
                                countries: viewModel.peerCountries
                            )
                        } label: {
                            Label("View All Peers (\(peers.count))", systemImage: "person.2")
                        }
                    }
                }

                if let trackers = detail.trackers, !trackers.isEmpty {
                    Section("Trackers") {
                        NavigationLink {
                            TrackerListView(
                                torrentId: torrent.id,
                                trackers: trackers,
                                trackerStats: detail.trackerStats ?? [],
                                viewModel: viewModel
                            )
                        } label: {
                            Label("View Trackers (\(trackers.count))", systemImage: "antenna.radiowaves.left.and.right")
                        }
                    }
                }

                if let files = detail.files, !files.isEmpty {
                    Section("Files (\(files.count))") {
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
                        }
                    }
                }

                Section("Info") {
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
                    if let creator = detail.creator, !creator.isEmpty {
                        row("Creator", value: creator)
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
                        row("Private", value: "Yes")
                    }
                    if let pieces = detail.pieceCount, let pieceSize = detail.pieceSize {
                        row("Pieces", value: "\(pieces) × \(FormatUtils.fileSize(pieceSize))")
                    }
                    if let added = detail.addedDate, added > 0 {
                        row("Added", value: formatDate(added))
                    }
                    if let done = detail.doneDate, done > 0 {
                        row("Completed", value: formatDate(done))
                    }
                }

                Section {
                    HStack(spacing: 12) {
                        if torrent.status == 0 {
                            Button {
                                Task {
                                    await viewModel.startTorrent(settings.config(for: .transmission), id: torrent.id)
                                    dismiss()
                                }
                            } label: {
                                Label("Start", systemImage: "play.fill")
                                    .frame(maxWidth: .infinity)
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
                                Label("Stop", systemImage: "stop.fill")
                                    .frame(maxWidth: .infinity)
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
                            Label("Verify", systemImage: "checkmark.shield")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Remove Torrent", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .navigationTitle(torrent.name ?? "Torrent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await viewModel.fetchTorrentDetail(settings.config(for: .transmission), id: torrent.id, showFlags: settings.showPeerFlags)
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

    private func row(_ label: String, value: String) -> some View {
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
