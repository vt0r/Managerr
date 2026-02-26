import Testing
import Foundation
@testable import Managerr

@MainActor
struct LidarrViewModelTests {

    // MARK: - Helpers

    private func makeArtist(
        id: Int = 1,
        artistName: String? = "Test Artist",
        sortName: String? = nil,
        added: String? = nil
    ) -> LidarrArtist {
        var dict: [String: Any] = ["id": id, "monitored": true]
        if let v = artistName { dict["artistName"] = v }
        if let v = sortName   { dict["sortName"]   = v }
        if let v = added      { dict["added"]      = v }
        let data = try! JSONSerialization.data(withJSONObject: dict)
        return try! JSONDecoder().decode(LidarrArtist.self, from: data)
    }

    private func makeAlbum(
        id: Int = 1,
        title: String? = "Test Album",
        artistName: String? = nil,
        releaseDate: String? = nil
    ) -> LidarrAlbum {
        let artist = artistName.map { LidarrAlbumArtist(id: nil, artistName: $0) }
        return LidarrAlbum(
            id: id, title: title, overview: nil, artistId: nil, monitored: true,
            albumType: nil, genres: nil, images: nil, ratings: nil,
            releaseDate: releaseDate, duration: nil, artist: artist, statistics: nil
        )
    }

    // MARK: - filteredArtists: Search

    @Test func filteredArtists_emptySearch_returnsAll() {
        let vm = LidarrViewModel()
        vm.artists = [makeArtist(id: 1), makeArtist(id: 2)]
        vm.searchText = ""
        #expect(vm.filteredArtists.count == 2)
    }

    @Test func filteredArtists_search_filtersByArtistName() {
        let vm = LidarrViewModel()
        vm.artists = [
            makeArtist(id: 1, artistName: "Radiohead"),
            makeArtist(id: 2, artistName: "Portishead"),
            makeArtist(id: 3, artistName: "Bjork"),
        ]
        vm.searchText = "head"
        let ids = vm.filteredArtists.map(\.id)
        #expect(ids.contains(1))
        #expect(ids.contains(2))
        #expect(!ids.contains(3))
    }

    @Test func filteredArtists_search_caseInsensitive() {
        let vm = LidarrViewModel()
        vm.artists = [makeArtist(artistName: "Radiohead")]
        vm.searchText = "RADIO"
        #expect(vm.filteredArtists.count == 1)
    }

    // MARK: - filteredArtists: Sort

    @Test func filteredArtists_alphabetical_sortsBySortName() {
        let vm = LidarrViewModel()
        vm.artists = [
            makeArtist(id: 1, artistName: "The Beatles", sortName: "beatles"),
            makeArtist(id: 2, artistName: "Radiohead",   sortName: "radiohead"),
            makeArtist(id: 3, artistName: "Adele",       sortName: "adele"),
        ]
        vm.sortOrder = .alphabetical
        let ids = vm.filteredArtists.map(\.id)
        #expect(ids == [3, 1, 2]) // adele < beatles < radiohead
    }

    @Test func filteredArtists_alphabetical_fallsBackToArtistName() {
        let vm = LidarrViewModel()
        vm.artists = [
            makeArtist(id: 1, artistName: "Zeppelin", sortName: nil),
            makeArtist(id: 2, artistName: "Adele",    sortName: nil),
        ]
        vm.sortOrder = .alphabetical
        #expect(vm.filteredArtists.first?.id == 2)
    }

    @Test func filteredArtists_dateAdded_sortsDescending() {
        let vm = LidarrViewModel()
        vm.artists = [
            makeArtist(id: 1, added: "2021-01-01"),
            makeArtist(id: 2, added: "2024-05-10"),
            makeArtist(id: 3, added: "2018-12-31"),
        ]
        vm.sortOrder = .dateAdded
        let ids = vm.filteredArtists.map(\.id)
        #expect(ids == [2, 1, 3])
    }

    // MARK: - filteredAlbums: Search

    @Test func filteredAlbums_emptySearch_returnsAll() {
        let vm = LidarrViewModel()
        vm.albums = [makeAlbum(id: 1), makeAlbum(id: 2)]
        vm.searchText = ""
        #expect(vm.filteredAlbums.count == 2)
    }

    @Test func filteredAlbums_search_filtersByTitle() {
        let vm = LidarrViewModel()
        vm.albums = [
            makeAlbum(id: 1, title: "OK Computer"),
            makeAlbum(id: 2, title: "Kid A"),
        ]
        vm.searchText = "ok"
        let ids = vm.filteredAlbums.map(\.id)
        #expect(ids == [1])
    }

    @Test func filteredAlbums_search_filtersByArtistName() {
        let vm = LidarrViewModel()
        vm.albums = [
            makeAlbum(id: 1, title: "OK Computer",   artistName: "Radiohead"),
            makeAlbum(id: 2, title: "The Bends",     artistName: "Radiohead"),
            makeAlbum(id: 3, title: "Dummy",         artistName: "Portishead"),
        ]
        vm.searchText = "radiohead"
        let ids = vm.filteredAlbums.map(\.id)
        #expect(ids.contains(1))
        #expect(ids.contains(2))
        #expect(!ids.contains(3))
    }

    @Test func filteredAlbums_search_matchesTitleOrArtist() {
        let vm = LidarrViewModel()
        vm.albums = [
            makeAlbum(id: 1, title: "Pablo Honey",   artistName: "Radiohead"),
            makeAlbum(id: 2, title: "Dummy",         artistName: "Portishead"),
            makeAlbum(id: 3, title: "Vespertine",    artistName: "Bjork"),
        ]
        vm.searchText = "head" // matches "Radiohead" and "Portishead" artist names
        let ids = vm.filteredAlbums.map(\.id)
        #expect(ids.contains(1))
        #expect(ids.contains(2))
        #expect(!ids.contains(3))
    }

    // MARK: - filteredAlbums: Sort

    @Test func filteredAlbums_alphabetical_sortsByTitle() {
        let vm = LidarrViewModel()
        vm.albums = [
            makeAlbum(id: 1, title: "OK Computer"),
            makeAlbum(id: 2, title: "Amnesiac"),
            makeAlbum(id: 3, title: "Kid A"),
        ]
        vm.sortOrder = .alphabetical
        let ids = vm.filteredAlbums.map(\.id)
        #expect(ids == [2, 3, 1]) // Amnesiac < Kid A < OK Computer
    }

    @Test func filteredAlbums_dateAdded_sortsByReleaseDateDescending() {
        let vm = LidarrViewModel()
        vm.albums = [
            makeAlbum(id: 1, releaseDate: "2001-06-05"),
            makeAlbum(id: 2, releaseDate: "2003-09-29"),
            makeAlbum(id: 3, releaseDate: "1995-09-26"),
        ]
        vm.sortOrder = .dateAdded
        let ids = vm.filteredAlbums.map(\.id)
        #expect(ids == [2, 1, 3])
    }
}
