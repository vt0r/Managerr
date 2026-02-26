import Testing
import Foundation
@testable import Managerr

@MainActor
struct RadarrViewModelTests {

    // MARK: - Helpers

    private func makeMovie(
        id: Int = 1,
        title: String = "Test",
        sortTitle: String? = nil,
        year: Int? = nil,
        added: String? = nil,
        sizeOnDisk: Int64? = nil
    ) -> RadarrMovie {
        var dict: [String: Any] = ["id": id, "title": title, "monitored": true, "hasFile": true]
        if let v = sortTitle  { dict["sortTitle"]  = v }
        if let v = year       { dict["year"]       = v }
        if let v = added      { dict["added"]      = v }
        if let v = sizeOnDisk { dict["sizeOnDisk"] = v }
        let data = try! JSONSerialization.data(withJSONObject: dict)
        return try! JSONDecoder().decode(RadarrMovie.self, from: data)
    }

    // MARK: - Search

    @Test func filteredMovies_emptySearch_returnsAll() {
        let vm = RadarrViewModel()
        vm.movies = [makeMovie(id: 1, title: "Alpha"), makeMovie(id: 2, title: "Beta")]
        vm.searchText = ""
        #expect(vm.filteredMovies.count == 2)
    }

    @Test func filteredMovies_search_filtersTitle() {
        let vm = RadarrViewModel()
        vm.movies = [makeMovie(id: 1, title: "Inception"), makeMovie(id: 2, title: "Interstellar"), makeMovie(id: 3, title: "Dune")]
        vm.searchText = "in"
        let titles = vm.filteredMovies.map(\.title)
        #expect(titles.contains("Inception"))
        #expect(titles.contains("Interstellar"))
        #expect(!titles.contains("Dune"))
    }

    @Test func filteredMovies_search_caseInsensitive() {
        let vm = RadarrViewModel()
        vm.movies = [makeMovie(title: "Inception")]
        vm.searchText = "inception"
        #expect(vm.filteredMovies.count == 1)
    }

    @Test func filteredMovies_search_noMatch_returnsEmpty() {
        let vm = RadarrViewModel()
        vm.movies = [makeMovie(title: "Inception")]
        vm.searchText = "zzz"
        #expect(vm.filteredMovies.isEmpty)
    }

    // MARK: - Sort: Alphabetical

    @Test func filteredMovies_alphabetical_sortsBySortTitle() {
        let vm = RadarrViewModel()
        vm.movies = [
            makeMovie(id: 1, title: "The Matrix",  sortTitle: "matrix"),
            makeMovie(id: 2, title: "Alien",        sortTitle: "alien"),
            makeMovie(id: 3, title: "Blade Runner", sortTitle: "blade runner"),
        ]
        vm.sortOrder = .alphabetical
        let ids = vm.filteredMovies.map(\.id)
        #expect(ids == [2, 3, 1]) // alien < blade runner < matrix
    }

    @Test func filteredMovies_alphabetical_fallsBackToTitle() {
        let vm = RadarrViewModel()
        vm.movies = [
            makeMovie(id: 1, title: "Zulu"),
            makeMovie(id: 2, title: "Alpha"),
        ]
        vm.sortOrder = .alphabetical
        #expect(vm.filteredMovies.first?.id == 2)
    }

    // MARK: - Sort: Year

    @Test func filteredMovies_year_sortsDescending() {
        let vm = RadarrViewModel()
        vm.movies = [
            makeMovie(id: 1, year: 2010),
            makeMovie(id: 2, year: 2023),
            makeMovie(id: 3, year: 1999),
        ]
        vm.sortOrder = .year
        let ids = vm.filteredMovies.map(\.id)
        #expect(ids == [2, 1, 3])
    }

    @Test func filteredMovies_year_nilYearSortsLast() {
        let vm = RadarrViewModel()
        vm.movies = [
            makeMovie(id: 1, year: nil),
            makeMovie(id: 2, year: 2020),
        ]
        vm.sortOrder = .year
        #expect(vm.filteredMovies.first?.id == 2)
    }

    // MARK: - Sort: Date Added

    @Test func filteredMovies_dateAdded_sortsDescending() {
        let vm = RadarrViewModel()
        vm.movies = [
            makeMovie(id: 1, added: "2022-01-01"),
            makeMovie(id: 2, added: "2024-06-15"),
            makeMovie(id: 3, added: "2020-12-31"),
        ]
        vm.sortOrder = .dateAdded
        let ids = vm.filteredMovies.map(\.id)
        #expect(ids == [2, 1, 3])
    }

    // MARK: - Sort: Size

    @Test func filteredMovies_size_sortsDescending() {
        let vm = RadarrViewModel()
        vm.movies = [
            makeMovie(id: 1, sizeOnDisk: 1_000_000),
            makeMovie(id: 2, sizeOnDisk: 5_000_000_000),
            makeMovie(id: 3, sizeOnDisk: 500_000),
        ]
        vm.sortOrder = .size
        let ids = vm.filteredMovies.map(\.id)
        #expect(ids == [2, 1, 3])
    }
}
