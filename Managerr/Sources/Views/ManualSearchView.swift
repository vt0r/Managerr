import SwiftUI

struct ManualSearchView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let fetchReleases: () async throws -> [ArrRelease]
    let grabRelease: (ArrRelease) async throws -> Void

    @State private var releases: [ArrRelease] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var grabbingGuid: String?
    @State private var expandedRejections: Set<String> = []
    @State private var filterApproved = false

    private var displayedReleases: [ArrRelease] {
        filterApproved ? releases.filter { $0.approved == true } : releases
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Searching indexers...")
                } else if let error = errorMessage {
                    ContentUnavailableView(
                        "Search Failed",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if displayedReleases.isEmpty {
                    ContentUnavailableView(
                        "No Releases Found",
                        systemImage: "magnifyingglass",
                        description: Text(filterApproved ? "Try disabling the Approved Only filter." : "No releases found from configured indexers.")
                    )
                } else {
                    List(displayedReleases) { release in
                        releaseRow(release)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Toggle("Approved Only", isOn: $filterApproved)
                        .toggleStyle(.button)
                        .tint(.green)
                        .font(.caption)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            await loadReleases()
        }
    }

    private func loadReleases() async {
        isLoading = true
        errorMessage = nil
        do {
            releases = try await fetchReleases()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @ViewBuilder
    private func releaseRow(_ release: ArrRelease) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(release.title ?? "Unknown Release")
                .font(.subheadline.weight(.medium))
                .lineLimit(2)

            HStack(spacing: 6) {
                if let indexer = release.indexer {
                    Text(indexer)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.tertiarySystemBackground), in: Capsule())
                }
                if let quality = release.qualityName {
                    Text(quality)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if release.isTorrent {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "doc.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                if let size = release.size {
                    Text(FormatUtils.fileSize(size))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if release.isTorrent, let seeders = release.seeders {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(.green)
                        Text("\(seeders)")
                    }
                    .font(.caption)
                    if let leechers = release.leechers {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(.orange)
                            Text("\(leechers)")
                        }
                        .font(.caption)
                    }
                }
                if let age = release.age {
                    Text("\(age)d")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                grabButton(release)
            }

            if release.isRejected, let rejections = release.rejections, !rejections.isEmpty {
                Button {
                    if expandedRejections.contains(release.guid) {
                        expandedRejections.remove(release.guid)
                    } else {
                        expandedRejections.insert(release.guid)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text("Rejected (\(rejections.count))")
                            .font(.caption)
                            .foregroundStyle(.red)
                        Image(systemName: expandedRejections.contains(release.guid) ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
                .buttonStyle(.plain)

                if expandedRejections.contains(release.guid) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(rejections, id: \.self) { reason in
                            Text("• \(reason)")
                                .font(.caption2)
                                .foregroundStyle(.red.opacity(0.8))
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(release.isRejected ? 0.7 : 1.0)
    }

    @ViewBuilder
    private func grabButton(_ release: ArrRelease) -> some View {
        Button {
            Task {
                grabbingGuid = release.guid
                do {
                    try await grabRelease(release)
                } catch {}
                grabbingGuid = nil
            }
        } label: {
            if grabbingGuid == release.guid {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 28, height: 28)
            } else {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title3)
                    .foregroundStyle(release.isRejected ? .orange : .accentColor)
            }
        }
        .accessibilityLabel("Download release")
        .frame(minWidth: 44, minHeight: 44)
        .disabled(grabbingGuid != nil)
    }
}
