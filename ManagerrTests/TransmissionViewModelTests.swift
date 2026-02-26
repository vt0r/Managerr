import Testing
import Foundation
@testable import Managerr

@MainActor
struct TransmissionViewModelTests {

    // MARK: - Helpers

    private func makeTorrent(
        id: Int = 1,
        name: String? = "Test",
        status: Int? = 4,
        rateDownload: Int64? = 0,
        rateUpload: Int64? = 0,
        addedDate: Int? = 0
    ) -> TransmissionTorrent {
        TransmissionTorrent(
            id: id, name: name, status: status, totalSize: nil, percentDone: nil,
            rateDownload: rateDownload, rateUpload: rateUpload, eta: nil,
            uploadRatio: nil, errorString: nil, error: nil, addedDate: addedDate,
            doneDate: nil, downloadDir: nil, sizeWhenDone: nil, leftUntilDone: nil,
            uploadedEver: nil, downloadedEver: nil, peersConnected: nil,
            peersSendingToUs: nil, peersGettingFromUs: nil, hashString: nil,
            peers: nil, trackers: nil, trackerStats: nil, files: nil, fileStats: nil,
            pieceCount: nil, pieceSize: nil, creator: nil, comment: nil,
            isPrivate: nil, magnetLink: nil
        )
    }

    // MARK: - filteredTorrents: Search

    @Test func filteredTorrents_emptySearch_returnsAll() {
        let vm = TransmissionViewModel()
        vm.torrents = [makeTorrent(id: 1), makeTorrent(id: 2)]
        vm.searchText = ""
        #expect(vm.filteredTorrents.count == 2)
    }

    @Test func filteredTorrents_search_filtersByName() {
        let vm = TransmissionViewModel()
        vm.torrents = [
            makeTorrent(id: 1, name: "Ubuntu ISO"),
            makeTorrent(id: 2, name: "Debian ISO"),
            makeTorrent(id: 3, name: "Arch Setup"),
        ]
        vm.searchText = "iso"
        let ids = vm.filteredTorrents.map(\.id)
        #expect(ids.contains(1))
        #expect(ids.contains(2))
        #expect(!ids.contains(3))
    }

    @Test func filteredTorrents_search_caseInsensitive() {
        let vm = TransmissionViewModel()
        vm.torrents = [makeTorrent(name: "Ubuntu ISO")]
        vm.searchText = "UBUNTU"
        #expect(vm.filteredTorrents.count == 1)
    }

    // MARK: - filteredTorrents: Status Filter

    @Test func filteredTorrents_all_includesEverything() {
        let vm = TransmissionViewModel()
        vm.torrents = [
            makeTorrent(id: 1, status: 0),
            makeTorrent(id: 2, status: 4),
            makeTorrent(id: 3, status: 6),
        ]
        vm.filterStatus = .all
        #expect(vm.filteredTorrents.count == 3)
    }

    @Test func filteredTorrents_downloading_includesStatuses3and4() {
        let vm = TransmissionViewModel()
        vm.torrents = [
            makeTorrent(id: 1, status: 0),
            makeTorrent(id: 2, status: 3),
            makeTorrent(id: 3, status: 4),
            makeTorrent(id: 4, status: 6),
        ]
        vm.filterStatus = .downloading
        let ids = vm.filteredTorrents.map(\.id)
        #expect(ids.contains(2))
        #expect(ids.contains(3))
        #expect(!ids.contains(1))
        #expect(!ids.contains(4))
    }

    @Test func filteredTorrents_seeding_includesStatuses5and6() {
        let vm = TransmissionViewModel()
        vm.torrents = [
            makeTorrent(id: 1, status: 4),
            makeTorrent(id: 2, status: 5),
            makeTorrent(id: 3, status: 6),
        ]
        vm.filterStatus = .seeding
        let ids = vm.filteredTorrents.map(\.id)
        #expect(ids.contains(2))
        #expect(ids.contains(3))
        #expect(!ids.contains(1))
    }

    @Test func filteredTorrents_stopped_includesOnlyStatus0() {
        let vm = TransmissionViewModel()
        vm.torrents = [
            makeTorrent(id: 1, status: 0),
            makeTorrent(id: 2, status: 4),
            makeTorrent(id: 3, status: 6),
        ]
        vm.filterStatus = .stopped
        let ids = vm.filteredTorrents.map(\.id)
        #expect(ids == [1])
    }

    // MARK: - filteredTorrents: Sort by addedDate

    @Test func filteredTorrents_sortedByAddedDateDescending() {
        let vm = TransmissionViewModel()
        vm.torrents = [
            makeTorrent(id: 1, addedDate: 1_000_000),
            makeTorrent(id: 2, addedDate: 3_000_000),
            makeTorrent(id: 3, addedDate: 2_000_000),
        ]
        let ids = vm.filteredTorrents.map(\.id)
        #expect(ids == [2, 3, 1])
    }

    @Test func filteredTorrents_nilAddedDateSortsLast() {
        let vm = TransmissionViewModel()
        vm.torrents = [
            makeTorrent(id: 1, addedDate: nil),
            makeTorrent(id: 2, addedDate: 1_000),
        ]
        let ids = vm.filteredTorrents.map(\.id)
        #expect(ids.first == 2)
    }

    // MARK: - totalDownloadSpeed

    @Test func totalDownloadSpeed_emptyTorrents_returnsZero() {
        let vm = TransmissionViewModel()
        vm.torrents = []
        #expect(vm.totalDownloadSpeed == 0)
    }

    @Test func totalDownloadSpeed_sumsAllRates() {
        let vm = TransmissionViewModel()
        vm.torrents = [
            makeTorrent(id: 1, rateDownload: 500_000),
            makeTorrent(id: 2, rateDownload: 1_500_000),
            makeTorrent(id: 3, rateDownload: 0),
        ]
        #expect(vm.totalDownloadSpeed == 2_000_000)
    }

    @Test func totalDownloadSpeed_nilRateTreatedAsZero() {
        let vm = TransmissionViewModel()
        vm.torrents = [
            makeTorrent(id: 1, rateDownload: nil),
            makeTorrent(id: 2, rateDownload: 1_000_000),
        ]
        #expect(vm.totalDownloadSpeed == 1_000_000)
    }

    // MARK: - totalUploadSpeed

    @Test func totalUploadSpeed_emptyTorrents_returnsZero() {
        let vm = TransmissionViewModel()
        vm.torrents = []
        #expect(vm.totalUploadSpeed == 0)
    }

    @Test func totalUploadSpeed_sumsAllRates() {
        let vm = TransmissionViewModel()
        vm.torrents = [
            makeTorrent(id: 1, rateUpload: 100_000),
            makeTorrent(id: 2, rateUpload: 200_000),
        ]
        #expect(vm.totalUploadSpeed == 300_000)
    }

    @Test func totalUploadSpeed_nilRateTreatedAsZero() {
        let vm = TransmissionViewModel()
        vm.torrents = [
            makeTorrent(id: 1, rateUpload: nil),
            makeTorrent(id: 2, rateUpload: 250_000),
        ]
        #expect(vm.totalUploadSpeed == 250_000)
    }
}
