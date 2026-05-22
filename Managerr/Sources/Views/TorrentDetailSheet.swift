import SwiftUI

struct TorrentDetailSheet: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss
    let torrent: TransmissionTorrent
    let viewModel: TransmissionViewModel

    @State private var showDeleteConfirmation: Bool = false
    @State private var showMoveLocationSheet: Bool = false

    private enum EditField: Hashable {
        case downloadLimit, uploadLimit, peerLimit, ratioLimit, idleLimit, newLabel
    }
    @FocusState private var focusedField: EditField?
    @State private var downloadLimitText = ""
    @State private var uploadLimitText = ""
    @State private var peerLimitText = ""
    @State private var ratioLimitText = ""
    @State private var idleLimitText = ""
    @State private var newLabelText = ""

    private var detail: TransmissionTorrent {
        viewModel.detailedTorrent ?? torrent
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    progressHeader
                    transferSection
                    bandwidthSection
                    connectionsSection
                    seedingSection
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
                        filesSection(files, fileStats: detail.fileStats ?? [])
                    }

                    labelsSection
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
            .onAppear { syncEditFields() }
            .onChange(of: viewModel.detailedTorrent) { _, _ in syncEditFields() }
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
            .sheet(isPresented: $showMoveLocationSheet) {
                LocationMoveSheet(
                    currentPath: detail.downloadDir ?? "",
                    torrentId: torrent.id,
                    viewModel: viewModel
                )
            }
        }
    }

    // MARK: - Sync edit fields from model (skips focused fields)

    private func syncEditFields() {
        if focusedField != .downloadLimit {
            downloadLimitText = detail.speedLimitDown.map(String.init) ?? ""
        }
        if focusedField != .uploadLimit {
            uploadLimitText = detail.speedLimitUp.map(String.init) ?? ""
        }
        if focusedField != .peerLimit {
            peerLimitText = detail.peerLimit.map(String.init) ?? ""
        }
        if focusedField != .ratioLimit {
            ratioLimitText = detail.seedRatioLimit.map { String(format: "%.2f", $0) } ?? ""
        }
        if focusedField != .idleLimit {
            idleLimitText = detail.seedIdleLimit.map(String.init) ?? ""
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
                .accessibilityHidden(true)

            if let errorStr = detail.errorString, !errorStr.isEmpty, detail.error != 0 {
                Text(errorStr)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if detail.isActive {
                HStack(spacing: 20) {
                    if let dl = detail.rateDownload, dl > 0 {
                        Label(FormatUtils.speed(dl), systemImage: "arrow.down.circle.fill")
                            .foregroundStyle(.blue)
                    }
                    if let ul = detail.rateUpload, ul > 0 {
                        Label(FormatUtils.speed(ul), systemImage: "arrow.up.circle.fill")
                            .foregroundStyle(.green)
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
                if let avail = detail.availability {
                    statCell("Availability", FormatUtils.percentage(avail))
                }
                if let selected = detail.sizeWhenDone, let total = detail.totalSize, selected != total {
                    statCell("Selected", FormatUtils.fileSize(selected))
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Bandwidth

    private var bandwidthSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bandwidth")
                .font(.headline)

            VStack(spacing: 0) {
                HStack {
                    Label("Priority", systemImage: "dial.medium")
                        .font(.subheadline)
                    Spacer()
                    Picker("Priority", selection: Binding(
                        get: { TorrentPriority(rawValue: detail.bandwidthPriority ?? 0) ?? .normal },
                        set: { p in
                            Task {
                                await viewModel.setTorrentPriority(settings.config(for: .transmission), id: torrent.id, priority: p.rawValue)
                            }
                        }
                    )) {
                        ForEach(TorrentPriority.allCases, id: \.rawValue) { p in
                            Text(p.label).tag(p)
                        }
                    }
                    .labelsHidden()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                Divider().padding(.leading, 12)

                speedLimitRow(
                    download: true,
                    enabled: detail.speedLimitDownEnabled ?? false,
                    limitText: $downloadLimitText,
                    focusField: .downloadLimit,
                    globalEnabled: viewModel.session?.speedLimitDownEnabled,
                    globalLimit: viewModel.session?.speedLimitDown
                )

                Divider().padding(.leading, 12)

                speedLimitRow(
                    download: false,
                    enabled: detail.speedLimitUpEnabled ?? false,
                    limitText: $uploadLimitText,
                    focusField: .uploadLimit,
                    globalEnabled: viewModel.session?.speedLimitUpEnabled,
                    globalLimit: viewModel.session?.speedLimitUp
                )
            }
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private func speedLimitRow(
        download: Bool,
        enabled: Bool,
        limitText: Binding<String>,
        focusField: EditField,
        globalEnabled: Bool?,
        globalLimit: Int?
    ) -> some View {
        let icon = download ? "arrow.down.circle" : "arrow.up.circle"
        let label = download ? "Download Speed Limit" : "Upload Speed Limit"

        VStack(alignment: .leading, spacing: 0) {
            Toggle(isOn: Binding(
                get: { enabled },
                set: { newVal in
                    Task {
                        await viewModel.setTorrentSpeedLimitEnabled(
                            settings.config(for: .transmission),
                            id: torrent.id, download: download, enabled: newVal
                        )
                    }
                }
            )) {
                Label(label, systemImage: icon)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            if enabled {
                HStack {
                    TextField("KB/s", text: limitText)
                        .focused($focusedField, equals: focusField)
                        .keyboardType(.numberPad)
                        .onSubmit {
                            guard let kb = Int(limitText.wrappedValue), kb >= 0 else { return }
                            Task {
                                await viewModel.setTorrentSpeedLimitValue(
                                    settings.config(for: .transmission),
                                    id: torrent.id, download: download, limit: kb
                                )
                            }
                        }
                    Text("KB/s")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            } else {
                Group {
                    if globalEnabled == true, let gLimit = globalLimit {
                        Text("Global limit: \(gLimit) KB/s")
                    } else {
                        Text("No global limit")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Connections

    private var connectionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Connections")
                .font(.headline)

            VStack(spacing: 0) {
                HStack {
                    Label("Peer Limit", systemImage: "person.2")
                        .font(.subheadline)
                    Spacer()
                    TextField("", text: $peerLimitText)
                        .focused($focusedField, equals: .peerLimit)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 64)
                        .onSubmit {
                            guard let limit = Int(peerLimitText), limit > 0 else { return }
                            Task {
                                await viewModel.setTorrentPeerLimit(
                                    settings.config(for: .transmission), id: torrent.id, limit: limit
                                )
                            }
                        }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                if let globalPeer = viewModel.session?.peerLimitPerTorrent {
                    Divider().padding(.leading, 12)
                    HStack {
                        Text("Global default")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(globalPeer)")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Seeding

    private var seedingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Seeding")
                .font(.headline)

            VStack(spacing: 0) {
                seedingModeRow(
                    label: "Ratio Limit",
                    icon: "arrow.left.arrow.right",
                    mode: detail.seedRatioMode ?? 0
                ) { newMode in
                    let ratio = Double(ratioLimitText)
                        ?? detail.seedRatioLimit
                        ?? viewModel.session?.seedRatioLimit
                        ?? 1.0
                    Task {
                        await viewModel.setTorrentSeedRatio(
                            settings.config(for: .transmission), id: torrent.id, mode: newMode, limit: ratio
                        )
                    }
                }

                if detail.seedRatioMode == 1 {
                    HStack {
                        TextField("1.00", text: $ratioLimitText)
                            .focused($focusedField, equals: .ratioLimit)
                            .keyboardType(.decimalPad)
                            .onSubmit {
                                guard let ratio = Double(ratioLimitText), ratio >= 0 else { return }
                                Task {
                                    await viewModel.setTorrentSeedRatio(
                                        settings.config(for: .transmission), id: torrent.id, mode: 1, limit: ratio
                                    )
                                }
                            }
                        Text("ratio")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                } else if detail.seedRatioMode == 0, let sessionRatio = viewModel.session?.seedRatioLimit {
                    HStack {
                        let limited = viewModel.session?.seedRatioLimited ?? false
                        Text(limited ? "Global: \(String(format: "%.2f", sessionRatio))" : "Global: unlimited")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }

                Divider().padding(.leading, 12)

                seedingModeRow(
                    label: "Idle Limit",
                    icon: "timer",
                    mode: detail.seedIdleMode ?? 0
                ) { newMode in
                    let mins = Int(idleLimitText)
                        ?? detail.seedIdleLimit
                        ?? viewModel.session?.seedIdleLimit
                        ?? 30
                    Task {
                        await viewModel.setTorrentSeedIdle(
                            settings.config(for: .transmission), id: torrent.id, mode: newMode, limit: mins
                        )
                    }
                }

                if detail.seedIdleMode == 1 {
                    HStack {
                        TextField("30", text: $idleLimitText)
                            .focused($focusedField, equals: .idleLimit)
                            .keyboardType(.numberPad)
                            .onSubmit {
                                guard let mins = Int(idleLimitText), mins > 0 else { return }
                                Task {
                                    await viewModel.setTorrentSeedIdle(
                                        settings.config(for: .transmission), id: torrent.id, mode: 1, limit: mins
                                    )
                                }
                            }
                        Text("min")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                } else if detail.seedIdleMode == 0, let sessionIdle = viewModel.session?.seedIdleLimit {
                    HStack {
                        let limited = viewModel.session?.seedIdleLimited ?? false
                        Text(limited ? "Global: \(sessionIdle) min" : "Global: unlimited")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

            Text("When a limit is reached, Transmission stops seeding the torrent. The idle limit triggers after the specified minutes with no upload or download activity.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    private func seedingModeRow(
        label: String,
        icon: String,
        mode: Int,
        onModeChange: @escaping (Int) -> Void
    ) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.subheadline)
            Spacer()
            Picker("", selection: Binding(get: { mode }, set: { onModeChange($0) })) {
                Text("Global").tag(0)
                Text("Custom").tag(1)
                Text("Unlimited").tag(2)
            }
            .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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

    private func filesSection(_ files: [TransmissionFile], fileStats: [TransmissionFileStats]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Files (\(files.count))")
                .font(.headline)

            ForEach(Array(files.enumerated()), id: \.element.id) { index, file in
                let stats = index < fileStats.count ? fileStats[index] : nil
                let priority = TorrentPriority(rawValue: stats?.priority ?? 0) ?? .normal
                let wanted = stats?.wanted ?? true

                HStack(alignment: .center, spacing: 8) {
                    Button {
                        Task {
                            await viewModel.setFilesWanted(
                                settings.config(for: .transmission),
                                id: torrent.id,
                                fileIndices: [index],
                                wanted: !wanted
                            )
                        }
                    } label: {
                        Image(systemName: wanted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(wanted ? .green : Color(.tertiaryLabel))
                            .font(.body)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(wanted ? "File included" : "File excluded")
                    .accessibilityHint("Toggles whether this file is downloaded")

                    VStack(alignment: .leading, spacing: 4) {
                        Text(fileName(file.name))
                            .font(.caption)
                            .lineLimit(2)
                            .foregroundStyle(wanted ? Color(.label) : .secondary)

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
                                    .opacity(wanted ? 1 : 0.4)
                                    .accessibilityLabel(String(format: "%.0f%% downloaded", Double(completed) / Double(total) * 100))
                            }
                        }
                    }

                    Spacer()

                    Menu {
                        ForEach(TorrentPriority.allCases, id: \.rawValue) { p in
                            Button {
                                Task {
                                    await viewModel.setFilePriority(
                                        settings.config(for: .transmission),
                                        id: torrent.id,
                                        fileIndices: [index],
                                        priority: p.rawValue
                                    )
                                }
                            } label: {
                                Label(p.label, systemImage: p.icon)
                            }
                        }
                    } label: {
                        Image(systemName: priority.icon)
                            .font(.caption)
                            .foregroundStyle(priority == .normal ? Color(.tertiaryLabel) : priority.color)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Priority: \(priority.label)")
                }
                .padding(.vertical, 2)

                if index != files.count - 1 {
                    Divider()
                }
            }
        }
    }

    // MARK: - Labels

    private var labelsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Labels")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                let labels = detail.labels ?? []

                if !labels.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(labels, id: \.self) { label in
                                HStack(spacing: 4) {
                                    Text(label)
                                        .font(.caption.weight(.medium))
                                    Button {
                                        let newLabels = labels.filter { $0 != label }
                                        Task {
                                            await viewModel.setTorrentLabels(
                                                settings.config(for: .transmission), id: torrent.id, labels: newLabels
                                            )
                                        }
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.caption2.weight(.semibold))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Remove label \(label)")
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color(.tertiarySystemBackground), in: Capsule())
                            }
                        }
                    }
                }

                HStack {
                    TextField("Add label…", text: $newLabelText)
                        .focused($focusedField, equals: .newLabel)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit { addLabel() }
                    Button(action: addLabel) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.tint)
                    }
                    .disabled(newLabelText.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityLabel("Add label")
                }
                .font(.subheadline)
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func addLabel() {
        let trimmed = newLabelText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var current = detail.labels ?? []
        guard !current.contains(trimmed) else { newLabelText = ""; return }
        current.append(trimmed)
        newLabelText = ""
        Task {
            await viewModel.setTorrentLabels(
                settings.config(for: .transmission), id: torrent.id, labels: current
            )
        }
    }

    // MARK: - Info

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Info")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                if let dir = detail.downloadDir {
                    Button {
                        showMoveLocationSheet = true
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Location")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(alignment: .firstTextBaseline) {
                                Text(dir)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: "pencil.circle")
                                    .font(.caption)
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Move download location")
                    .accessibilityValue(dir)
                    .accessibilityHint("Opens location move sheet")
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

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Queue Position")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let pos = detail.queuePosition {
                        Text("#\(pos + 1)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 8) {
                    queueButton("Top", "arrow.up.to.line", .top)
                    queueButton("Up", "arrow.up", .up)
                    queueButton("Down", "arrow.down", .down)
                    queueButton("Bottom", "arrow.down.to.line", .bottom)
                }
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

    @ViewBuilder
    private func queueButton(_ label: String, _ icon: String, _ dir: QueueDirection) -> some View {
        Button {
            Task {
                await viewModel.moveTorrentQueue(
                    settings.config(for: .transmission), id: torrent.id, direction: dir
                )
            }
        } label: {
            Image(systemName: icon).frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(label)
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

    private var statusColor: Color { detail.statusColor }

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

// MARK: - Location Move Sheet

private struct LocationMoveSheet: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss
    let currentPath: String
    let torrentId: Int
    let viewModel: TransmissionViewModel

    @State private var location: String
    @State private var moveFiles: Bool = true
    @State private var isSaving: Bool = false

    init(currentPath: String, torrentId: Int, viewModel: TransmissionViewModel) {
        self.currentPath = currentPath
        self.torrentId = torrentId
        self.viewModel = viewModel
        _location = State(initialValue: currentPath)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Path", text: $location)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                } header: {
                    Text("Download Location")
                } footer: {
                    Text("The directory where the torrent's files are saved.")
                }

                Section {
                    Toggle("Move Files to New Location", isOn: $moveFiles)
                } footer: {
                    Text(moveFiles
                         ? "Existing files will be moved to the new path."
                         : "Location preference will update but files stay in place.")
                }
            }
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(moveFiles ? "Move" : "Change") {
                        isSaving = true
                        Task {
                            await viewModel.setTorrentLocation(
                                settings.config(for: .transmission),
                                id: torrentId,
                                location: location,
                                move: moveFiles
                            )
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(location.trimmingCharacters(in: .whitespaces).isEmpty || location == currentPath || isSaving)
                }
            }
        }
    }
}
