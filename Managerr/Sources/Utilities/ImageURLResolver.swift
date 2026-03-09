import Foundation

nonisolated enum ImageURLResolver {
    /// Returns the URL as a string with query parameters removed, safe to include in log messages.
    static func redacted(_ url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = nil
        return components?.string ?? url.absoluteString
    }

    static func resolve(_ urlString: String?, baseURL: URL?) -> URL? {
        guard let urlString, !urlString.isEmpty else { return nil }
        if let url = URL(string: urlString), url.scheme != nil {
            return url
        }
        // Retry with percent-encoding for URLs with special characters
        if let encoded = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: encoded), url.scheme != nil {
            return url
        }
        guard let baseURL else { return nil }
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        if urlString.hasPrefix("/") {
            components?.path = urlString
        } else {
            let basePath = components?.path ?? ""
            components?.path = basePath + "/" + urlString
        }
        return components?.url
    }
}
