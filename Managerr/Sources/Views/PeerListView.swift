import SwiftUI

struct PeerListView: View {
    let peers: [TransmissionPeer]
    let countries: [String: String]

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Connected Peers")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text("\(peers.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(sortedPeers) { peer in
                PeerRow(peer: peer, countryCode: countries[peer.address ?? ""])
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Peers")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sortedPeers: [TransmissionPeer] {
        peers.sorted { lhs, rhs in
            let lhsRate: Int64 = (lhs.rateToClient ?? 0) + (lhs.rateToPeer ?? 0)
            let rhsRate: Int64 = (rhs.rateToClient ?? 0) + (rhs.rateToPeer ?? 0)
            return lhsRate > rhsRate
        }
    }
}

struct PeerRow: View {
    let peer: TransmissionPeer
    let countryCode: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if let code = countryCode {
                    Text(flagEmoji(for: code))
                        .font(.title3)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(peer.address ?? "Unknown")
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)

                    if let client = peer.clientName, !client.isEmpty {
                        Text(client)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if let progress = peer.progress {
                    Text(FormatUtils.percentage(progress))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                if let dl = peer.rateToClient, dl > 0 {
                    Label(FormatUtils.speed(dl), systemImage: "arrow.down")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
                if let ul = peer.rateToPeer, ul > 0 {
                    Label(FormatUtils.speed(ul), systemImage: "arrow.up")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }

                Spacer()

                HStack(spacing: 4) {
                    if peer.isEncrypted == true {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                    if peer.isUTP == true {
                        Text("µTP")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    if let flags = peer.flagStr, !flags.isEmpty {
                        Text(flags)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func flagEmoji(for countryCode: String) -> String {
        let base: UInt32 = 127397
        var emoji = ""
        for scalar in countryCode.uppercased().unicodeScalars {
            if let flag = Unicode.Scalar(base + scalar.value) {
                emoji.append(String(flag))
            }
        }
        return emoji
    }
}
