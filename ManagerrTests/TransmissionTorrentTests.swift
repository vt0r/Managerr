import Testing
@testable import Managerr

struct TransmissionTorrentTests {

    // MARK: - Helpers

    private func makeTorrent(status: Int?) -> TransmissionTorrent {
        TransmissionTorrent(
            id: 1, name: "Test", status: status, totalSize: nil, percentDone: nil,
            rateDownload: nil, rateUpload: nil, eta: nil, uploadRatio: nil,
            errorString: nil, error: nil, addedDate: nil, doneDate: nil,
            downloadDir: nil, sizeWhenDone: nil, leftUntilDone: nil,
            uploadedEver: nil, downloadedEver: nil, peersConnected: nil,
            peersSendingToUs: nil, peersGettingFromUs: nil, hashString: nil,
            peers: nil, trackers: nil, trackerStats: nil, files: nil, fileStats: nil,
            pieceCount: nil, pieceSize: nil, creator: nil, comment: nil,
            isPrivate: nil, magnetLink: nil
        )
    }

    // MARK: - statusText

    @Test func statusText_0_stopped() {
        #expect(makeTorrent(status: 0).statusText == "Stopped")
    }

    @Test func statusText_1_queuedToVerify() {
        #expect(makeTorrent(status: 1).statusText == "Queued to verify")
    }

    @Test func statusText_2_verifying() {
        #expect(makeTorrent(status: 2).statusText == "Verifying")
    }

    @Test func statusText_3_queuedToDownload() {
        #expect(makeTorrent(status: 3).statusText == "Queued to download")
    }

    @Test func statusText_4_downloading() {
        #expect(makeTorrent(status: 4).statusText == "Downloading")
    }

    @Test func statusText_5_queuedToSeed() {
        #expect(makeTorrent(status: 5).statusText == "Queued to seed")
    }

    @Test func statusText_6_seeding() {
        #expect(makeTorrent(status: 6).statusText == "Seeding")
    }

    @Test func statusText_nil_unknown() {
        #expect(makeTorrent(status: nil).statusText == "Unknown")
    }

    @Test func statusText_outOfRange_unknown() {
        #expect(makeTorrent(status: 99).statusText == "Unknown")
        #expect(makeTorrent(status: -1).statusText == "Unknown")
    }

    // MARK: - statusIcon

    @Test func statusIcon_0_pauseFill() {
        #expect(makeTorrent(status: 0).statusIcon == "pause.fill")
    }

    @Test func statusIcon_1_checkmarkShield() {
        #expect(makeTorrent(status: 1).statusIcon == "checkmark.shield")
    }

    @Test func statusIcon_2_checkmarkShield() {
        #expect(makeTorrent(status: 2).statusIcon == "checkmark.shield")
    }

    @Test func statusIcon_3_arrowDown() {
        #expect(makeTorrent(status: 3).statusIcon == "arrow.down")
    }

    @Test func statusIcon_4_arrowDown() {
        #expect(makeTorrent(status: 4).statusIcon == "arrow.down")
    }

    @Test func statusIcon_5_arrowUp() {
        #expect(makeTorrent(status: 5).statusIcon == "arrow.up")
    }

    @Test func statusIcon_6_arrowUp() {
        #expect(makeTorrent(status: 6).statusIcon == "arrow.up")
    }

    @Test func statusIcon_nil_questionmark() {
        #expect(makeTorrent(status: nil).statusIcon == "questionmark")
    }

    @Test func statusIcon_outOfRange_questionmark() {
        #expect(makeTorrent(status: 7).statusIcon == "questionmark")
    }

    // MARK: - isActive

    @Test func isActive_status4_true() {
        #expect(makeTorrent(status: 4).isActive == true)
    }

    @Test func isActive_status6_true() {
        #expect(makeTorrent(status: 6).isActive == true)
    }

    @Test func isActive_status0_false() {
        #expect(makeTorrent(status: 0).isActive == false)
    }

    @Test func isActive_status3_false() {
        #expect(makeTorrent(status: 3).isActive == false)
    }

    @Test func isActive_status5_false() {
        #expect(makeTorrent(status: 5).isActive == false)
    }

    @Test func isActive_nil_false() {
        #expect(makeTorrent(status: nil).isActive == false)
    }
}
