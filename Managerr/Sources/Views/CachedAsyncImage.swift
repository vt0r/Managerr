import SwiftUI

struct CachedAsyncImage: View {
    let url: URL?
    var fallbackURL: URL? = nil

    @State private var image: UIImage?
    @State private var hasFailed: Bool = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
            } else if hasFailed {
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
            } else {
                ProgressView()
                    .tint(.secondary)
            }
        }
        .task(id: url) {
            guard let url else {
                hasFailed = true
                return
            }
            if let loaded = await ImageLoader.shared.image(for: url) {
                withAnimation(UIAccessibility.isReduceMotionEnabled ? nil : .easeIn(duration: 0.15)) { image = loaded }
                return
            }
            if let fallbackURL, let loaded = await ImageLoader.shared.image(for: fallbackURL) {
                withAnimation(UIAccessibility.isReduceMotionEnabled ? nil : .easeIn(duration: 0.15)) { image = loaded }
                return
            }
            hasFailed = true
        }
    }
}
