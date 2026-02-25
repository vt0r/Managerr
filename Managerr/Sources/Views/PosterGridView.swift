import SwiftUI

struct PosterGridView: View {
    let imageURL: URL?
    let title: String
    let subtitle: String?
    let badge: String?
    let isMonitored: Bool
    var fallbackImageURL: URL? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Color(.secondarySystemBackground)
                .aspectRatio(2/3, contentMode: .fit)
                .overlay {
                    if let imageURL {
                        CachedAsyncImage(url: imageURL, fallbackURL: fallbackImageURL)
                            .allowsHitTesting(false)
                    } else {
                        posterPlaceholder
                    }
                }
                .clipShape(.rect(cornerRadius: 10))
                .overlay(alignment: .topLeading) {
                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(6)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if !isMonitored {
                        Image(systemName: "eye.slash.fill")
                            .font(.caption2)
                            .padding(5)
                            .background(.ultraThinMaterial, in: Circle())
                            .padding(6)
                    }
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(" ")
                        .font(.caption2)
                        .hidden()
                }
            }
            .frame(height: 38, alignment: .top)
        }
    }

    private var posterPlaceholder: some View {
        VStack(spacing: 4) {
            Image(systemName: "photo")
                .font(.title3)
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
        }
    }
}
