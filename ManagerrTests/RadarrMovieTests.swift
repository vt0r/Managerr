import Testing
import Foundation
@testable import Managerr

struct RadarrMovieTests {

    // MARK: - Helpers

    private func makeMovie(
        hasFile: Bool = false,
        status: String? = nil,
        images: [[String: String]] = []
    ) -> RadarrMovie {
        var dict: [String: Any] = [
            "id": 1,
            "title": "Test",
            "monitored": true,
            "hasFile": hasFile,
        ]
        if let v = status { dict["status"] = v }
        if !images.isEmpty { dict["images"] = images }
        let data = try! JSONSerialization.data(withJSONObject: dict)
        return try! JSONDecoder().decode(RadarrMovie.self, from: data)
    }

    // MARK: - gridBadge: hasFile suppresses badge

    @Test func gridBadge_hasFile_returnsNil() {
        let movie = makeMovie(hasFile: true, status: "released")
        #expect(movie.gridBadge == nil)
    }

    // MARK: - gridBadge: statuses without file

    @Test func gridBadge_releasedNoFile_returnsMissing() {
        #expect(makeMovie(hasFile: false, status: "released").gridBadge == "MISSING")
    }

    @Test func gridBadge_inCinemasNoFile_returnsInCinemas() {
        #expect(makeMovie(hasFile: false, status: "inCinemas").gridBadge == "IN CINEMAS")
    }

    @Test func gridBadge_announcedNoFile_returnsAnnounced() {
        #expect(makeMovie(hasFile: false, status: "announced").gridBadge == "ANNOUNCED")
    }

    @Test func gridBadge_tbaNoFile_returnsTBA() {
        #expect(makeMovie(hasFile: false, status: "tba").gridBadge == "TBA")
    }

    @Test func gridBadge_unknownStatusNoFile_returnsNil() {
        #expect(makeMovie(hasFile: false, status: "deleted").gridBadge == nil)
        #expect(makeMovie(hasFile: false, status: nil).gridBadge == nil)
    }

    // MARK: - posterImagePath

    @Test func posterImagePath_noImages_returnsNil() {
        let movie = makeMovie(images: [])
        #expect(movie.posterImagePath == nil)
    }

    @Test func posterImagePath_posterWithRemoteUrl_prefersRemoteUrl() {
        let movie = makeMovie(images: [
            ["coverType": "poster", "url": "/local/path.jpg", "remoteUrl": "https://cdn.example.com/poster.jpg"]
        ])
        #expect(movie.posterImagePath == "https://cdn.example.com/poster.jpg")
    }

    @Test func posterImagePath_posterWithoutRemoteUrl_fallsBackToUrl() {
        let movie = makeMovie(images: [
            ["coverType": "poster", "url": "/MediaCover/1/poster.jpg"]
        ])
        #expect(movie.posterImagePath == "/MediaCover/1/poster.jpg")
    }

    @Test func posterImagePath_fanartOnly_returnsNil() {
        let movie = makeMovie(images: [
            ["coverType": "fanart", "remoteUrl": "https://cdn.example.com/fanart.jpg"]
        ])
        #expect(movie.posterImagePath == nil)
    }

    @Test func posterImagePath_multipleCoverTypes_selectsPoster() {
        let movie = makeMovie(images: [
            ["coverType": "fanart",  "remoteUrl": "https://cdn.example.com/fanart.jpg"],
            ["coverType": "poster",  "remoteUrl": "https://cdn.example.com/poster.jpg"],
        ])
        #expect(movie.posterImagePath == "https://cdn.example.com/poster.jpg")
    }
}
