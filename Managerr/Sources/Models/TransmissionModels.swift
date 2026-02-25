import Foundation

nonisolated struct TransmissionRPCRequest: Codable, Sendable {
    let method: String
    let arguments: [String: AnyCodable]?
    let tag: Int?
}

nonisolated struct TransmissionRPCResponse: Codable, Sendable {
    let result: String
    let arguments: TransmissionArguments?
    let tag: Int?
}

nonisolated struct TransmissionArguments: Codable, Sendable {
    let torrents: [TransmissionTorrent]?
}

nonisolated struct TransmissionTorrent: Codable, Identifiable, Sendable {
    let id: Int
    let name: String?
    let status: Int?
    let totalSize: Int64?
    let percentDone: Double?
    let rateDownload: Int64?
    let rateUpload: Int64?
    let eta: Int?
    let uploadRatio: Double?
    let errorString: String?
    let error: Int?
    let addedDate: Int?
    let doneDate: Int?
    let downloadDir: String?
    let sizeWhenDone: Int64?
    let leftUntilDone: Int64?
    let uploadedEver: Int64?
    let downloadedEver: Int64?
    let peersConnected: Int?
    let peersSendingToUs: Int?
    let peersGettingFromUs: Int?
    let hashString: String?
    let peers: [TransmissionPeer]?
    let trackers: [TransmissionTracker]?
    let trackerStats: [TransmissionTrackerStats]?
    let files: [TransmissionFile]?
    let fileStats: [TransmissionFileStats]?
    let pieceCount: Int?
    let pieceSize: Int64?
    let creator: String?
    let comment: String?
    let isPrivate: Bool?
    let magnetLink: String?

    var statusText: String {
        switch status {
        case 0: "Stopped"
        case 1: "Queued to verify"
        case 2: "Verifying"
        case 3: "Queued to download"
        case 4: "Downloading"
        case 5: "Queued to seed"
        case 6: "Seeding"
        default: "Unknown"
        }
    }

    var statusIcon: String {
        switch status {
        case 0: "pause.fill"
        case 1, 2: "checkmark.shield"
        case 3, 4: "arrow.down"
        case 5, 6: "arrow.up"
        default: "questionmark"
        }
    }

    var isActive: Bool {
        status == 4 || status == 6
    }
}

nonisolated struct TransmissionPeer: Codable, Identifiable, Sendable {
    let address: String?
    let clientName: String?
    let flagStr: String?
    let isDownloadingFrom: Bool?
    let isEncrypted: Bool?
    let isIncoming: Bool?
    let isUploadingTo: Bool?
    let isUTP: Bool?
    let port: Int?
    let progress: Double?
    let rateToClient: Int64?
    let rateToPeer: Int64?

    var id: String { address ?? UUID().uuidString }
}

nonisolated struct TransmissionTracker: Codable, Identifiable, Sendable {
    let id: Int
    let announce: String?
    let scrape: String?
    let tier: Int?
}

nonisolated struct TransmissionTrackerStats: Codable, Identifiable, Sendable {
    let id: Int
    let announce: String?
    let announceState: Int?
    let downloadCount: Int?
    let hasAnnounced: Bool?
    let hasScraped: Bool?
    let host: String?
    let isBackup: Bool?
    let lastAnnouncePeerCount: Int?
    let lastAnnounceResult: String?
    let lastAnnounceSucceeded: Bool?
    let lastAnnounceTime: Int?
    let lastScrapeResult: String?
    let lastScrapeSucceeded: Bool?
    let leecherCount: Int?
    let seederCount: Int?
    let tier: Int?
}

nonisolated struct TransmissionFile: Codable, Identifiable, Sendable {
    let name: String?
    let length: Int64?
    let bytesCompleted: Int64?

    var id: String { name ?? UUID().uuidString }
}

nonisolated struct TransmissionFileStats: Codable, Sendable {
    let bytesCompleted: Int64?
    let wanted: Bool?
    let priority: Int?
}

nonisolated struct CountryResponse: Codable, Sendable {
    let ip: String?
    let country: String?
}

// Why the `@unchecked Sendable`?
// Because we're using the "init(from)" to check for a finite list of supported
// types, and if we don't find one, we set `value` to "null", so this _should_
// be safe (tm).
nonisolated struct AnyCodable: Codable, @unchecked Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map(\.value)
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues(\.value)
        } else {
            value = "null"
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let intValue = value as? Int {
            try container.encode(intValue)
        } else if let doubleValue = value as? Double {
            try container.encode(doubleValue)
        } else if let stringValue = value as? String {
            try container.encode(stringValue)
        } else if let boolValue = value as? Bool {
            try container.encode(boolValue)
        } else if let arrayValue = value as? [Any] {
            try container.encode(arrayValue.map { AnyCodable($0) })
        } else if let dictValue = value as? [String: Any] {
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        } else {
            try container.encodeNil()
        }
    }
}
