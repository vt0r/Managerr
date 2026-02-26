import Testing
import Foundation
@testable import Managerr

struct ImageURLResolverTests {

    private let base = URL(string: "http://192.168.1.10:7878")!

    // MARK: - nil / empty input

    @Test func resolve_nilString_returnsNil() {
        #expect(ImageURLResolver.resolve(nil, baseURL: base) == nil)
    }

    @Test func resolve_emptyString_returnsNil() {
        #expect(ImageURLResolver.resolve("", baseURL: base) == nil)
    }

    // MARK: - absolute URLs

    @Test func resolve_absoluteHTTPS_returnedAsIs() {
        let url = ImageURLResolver.resolve("https://image.tmdb.org/t/p/w500/abc.jpg", baseURL: base)
        #expect(url == URL(string: "https://image.tmdb.org/t/p/w500/abc.jpg"))
    }

    @Test func resolve_absoluteHTTP_returnedAsIs() {
        let url = ImageURLResolver.resolve("http://other.host/image.png", baseURL: base)
        #expect(url == URL(string: "http://other.host/image.png"))
    }

    @Test func resolve_absoluteURL_ignoresBaseURL() {
        let url = ImageURLResolver.resolve("https://cdn.example.com/img.jpg", baseURL: nil)
        #expect(url == URL(string: "https://cdn.example.com/img.jpg"))
    }

    // MARK: - relative paths (leading slash)

    @Test func resolve_leadingSlashPath_replacesBaseURLPath() {
        let url = ImageURLResolver.resolve("/MediaCover/1/poster.jpg", baseURL: base)
        #expect(url == URL(string: "http://192.168.1.10:7878/MediaCover/1/poster.jpg"))
    }

    @Test func resolve_leadingSlashPath_nilBase_returnsNil() {
        #expect(ImageURLResolver.resolve("/some/path.jpg", baseURL: nil) == nil)
    }

    // MARK: - relative paths (no leading slash)

    @Test func resolve_noLeadingSlash_appendedToBasePath() {
        let baseWithPath = URL(string: "http://192.168.1.10:7878/radarr")!
        let url = ImageURLResolver.resolve("poster.jpg", baseURL: baseWithPath)
        #expect(url == URL(string: "http://192.168.1.10:7878/radarr/poster.jpg"))
    }

    @Test func resolve_noLeadingSlash_nilBase_returnsNil() {
        #expect(ImageURLResolver.resolve("poster.jpg", baseURL: nil) == nil)
    }

    // MARK: - percent-encoding fallback

    @Test func resolve_urlWithSpaces_percentEncoded() {
        // A string with spaces is not a valid URL, so the resolver should percent-encode it
        let url = ImageURLResolver.resolve("https://example.com/my image.jpg", baseURL: base)
        #expect(url != nil)
    }
}
