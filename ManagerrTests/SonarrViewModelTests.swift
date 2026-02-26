import Testing
import Foundation
@testable import Managerr

@MainActor
struct SonarrViewModelTests {

    // MARK: - Helpers

    private func makeSeries(
        id: Int = 1,
        title: String = "Test",
        sortTitle: String? = nil,
        year: Int? = nil,
        added: String? = nil,
        network: String? = nil
    ) -> SonarrSeries {
        var dict: [String: Any] = ["id": id, "title": title, "monitored": true]
        if let v = sortTitle { dict["sortTitle"] = v }
        if let v = year      { dict["year"]      = v }
        if let v = added     { dict["added"]     = v }
        if let v = network   { dict["network"]   = v }
        let data = try! JSONSerialization.data(withJSONObject: dict)
        return try! JSONDecoder().decode(SonarrSeries.self, from: data)
    }

    // MARK: - Search

    @Test func filteredSeries_emptySearch_returnsAll() {
        let vm = SonarrViewModel()
        vm.series = [makeSeries(id: 1, title: "Breaking Bad"), makeSeries(id: 2, title: "Succession")]
        vm.searchText = ""
        #expect(vm.filteredSeries.count == 2)
    }

    @Test func filteredSeries_search_filtersTitle() {
        let vm = SonarrViewModel()
        vm.series = [makeSeries(title: "Breaking Bad"), makeSeries(title: "Better Call Saul"), makeSeries(title: "Succession")]
        vm.searchText = "b"
        let titles = vm.filteredSeries.map(\.title)
        #expect(titles.contains("Breaking Bad"))
        #expect(titles.contains("Better Call Saul"))
        #expect(!titles.contains("Succession"))
    }

    @Test func filteredSeries_search_caseInsensitive() {
        let vm = SonarrViewModel()
        vm.series = [makeSeries(title: "Breaking Bad")]
        vm.searchText = "BREAKING"
        #expect(vm.filteredSeries.count == 1)
    }

    // MARK: - Sort: Alphabetical

    @Test func filteredSeries_alphabetical_sortsBySortTitle() {
        let vm = SonarrViewModel()
        vm.series = [
            makeSeries(id: 1, title: "The Wire",   sortTitle: "wire"),
            makeSeries(id: 2, title: "Avatar",      sortTitle: "avatar"),
            makeSeries(id: 3, title: "Lost",        sortTitle: "lost"),
        ]
        vm.sortOrder = .alphabetical
        let ids = vm.filteredSeries.map(\.id)
        #expect(ids == [2, 3, 1]) // avatar < lost < wire
    }

    // MARK: - Sort: Year

    @Test func filteredSeries_year_sortsDescending() {
        let vm = SonarrViewModel()
        vm.series = [
            makeSeries(id: 1, year: 2005),
            makeSeries(id: 2, year: 2022),
            makeSeries(id: 3, year: 1998),
        ]
        vm.sortOrder = .year
        let ids = vm.filteredSeries.map(\.id)
        #expect(ids == [2, 1, 3])
    }

    // MARK: - Sort: Date Added

    @Test func filteredSeries_dateAdded_sortsDescending() {
        let vm = SonarrViewModel()
        vm.series = [
            makeSeries(id: 1, added: "2021-03-01"),
            makeSeries(id: 2, added: "2023-11-20"),
            makeSeries(id: 3, added: "2019-07-04"),
        ]
        vm.sortOrder = .dateAdded
        let ids = vm.filteredSeries.map(\.id)
        #expect(ids == [2, 1, 3])
    }

    // MARK: - Sort: Network

    @Test func filteredSeries_network_sortsAscending() {
        let vm = SonarrViewModel()
        vm.series = [
            makeSeries(id: 1, network: "Netflix"),
            makeSeries(id: 2, network: "AMC"),
            makeSeries(id: 3, network: "HBO"),
        ]
        vm.sortOrder = .network
        let ids = vm.filteredSeries.map(\.id)
        #expect(ids == [2, 3, 1]) // AMC < HBO < Netflix
    }

    @Test func filteredSeries_network_nilNetworkSortsFirst() {
        let vm = SonarrViewModel()
        vm.series = [
            makeSeries(id: 1, network: "NBC"),
            makeSeries(id: 2, network: nil),
        ]
        vm.sortOrder = .network
        // nil → "" which is less than "NBC"
        #expect(vm.filteredSeries.first?.id == 2)
    }
}
