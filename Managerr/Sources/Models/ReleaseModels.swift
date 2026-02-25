import Foundation

nonisolated struct ArrRelease: Codable, Identifiable, Sendable {
    let guid: String
    let indexerId: Int
    let indexer: String?
    let title: String?
    let size: Int64?
    let quality: ReleaseQualityWrapper?
    let seeders: Int?
    let leechers: Int?
    let `protocol`: String?
    let approved: Bool?
    let rejected: Bool?
    let rejections: [String]?
    let age: Int?
    let ageHours: Double?
    let infoUrl: String?
    let downloadAllowed: Bool?

    var id: String { guid }

    var isRejected: Bool { rejected == true }
    var qualityName: String? { quality?.quality?.name }
    var isTorrent: Bool { `protocol` == "torrent" }

    enum CodingKeys: String, CodingKey {
        case guid, indexerId, indexer, title, size, quality, seeders, leechers
        case `protocol`, approved, rejected, rejections, age, ageHours, infoUrl, downloadAllowed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guid = try c.decodeIfPresent(String.self, forKey: .guid) ?? ""
        indexerId = try c.decodeIfPresent(Int.self, forKey: .indexerId) ?? 0
        indexer = try c.decodeIfPresent(String.self, forKey: .indexer)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        size = try c.decodeIfPresent(Int64.self, forKey: .size)
        quality = try c.decodeIfPresent(ReleaseQualityWrapper.self, forKey: .quality)
        seeders = try c.decodeIfPresent(Int.self, forKey: .seeders)
        leechers = try c.decodeIfPresent(Int.self, forKey: .leechers)
        `protocol` = try c.decodeIfPresent(String.self, forKey: .protocol)
        approved = try c.decodeIfPresent(Bool.self, forKey: .approved)
        rejected = try c.decodeIfPresent(Bool.self, forKey: .rejected)
        rejections = try c.decodeIfPresent([String].self, forKey: .rejections)
        age = try c.decodeIfPresent(Int.self, forKey: .age)
        ageHours = try c.decodeIfPresent(Double.self, forKey: .ageHours)
        infoUrl = try c.decodeIfPresent(String.self, forKey: .infoUrl)
        downloadAllowed = try c.decodeIfPresent(Bool.self, forKey: .downloadAllowed)
    }
}

nonisolated struct ReleaseQualityWrapper: Codable, Sendable {
    let quality: ReleaseQuality?
}

nonisolated struct ReleaseQuality: Codable, Sendable {
    let id: Int?
    let name: String?
}

nonisolated struct ReleaseGrabRequest: Codable, Sendable {
    let guid: String
    let indexerId: Int
}
