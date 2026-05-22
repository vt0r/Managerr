import Foundation

actor TransmissionService {
    static let shared = TransmissionService()
    private var sessionId: String = ""

    private init() {}

    private let torrentFields: [String] = [
        "id", "name", "status", "totalSize", "percentDone",
        "rateDownload", "rateUpload", "eta", "uploadRatio",
        "errorString", "error", "addedDate", "doneDate",
        "downloadDir", "sizeWhenDone", "leftUntilDone",
        "uploadedEver", "downloadedEver", "peersConnected",
        "peersSendingToUs", "peersGettingFromUs", "hashString"
    ]

    private let detailFields: [String] = [
        "id", "name", "status", "totalSize", "percentDone",
        "rateDownload", "rateUpload", "eta", "uploadRatio",
        "errorString", "error", "addedDate", "doneDate",
        "downloadDir", "sizeWhenDone", "leftUntilDone",
        "uploadedEver", "downloadedEver", "peersConnected",
        "peersSendingToUs", "peersGettingFromUs", "hashString",
        "peers", "trackers", "trackerStats", "files", "fileStats",
        "pieceCount", "pieceSize", "creator", "comment", "isPrivate",
        "magnetLink", "desiredAvailable", "bandwidthPriority",
        "speed-limit-down-enabled", "speed-limit-down",
        "speed-limit-up-enabled", "speed-limit-up",
        "peer-limit", "seedRatioMode", "seedRatioLimit",
        "seedIdleMode", "seedIdleLimit", "labels", "queuePosition"
    ]

    private func rpcURL(_ config: ServerConfig) throws -> URL {
        guard let base = config.baseURL else { throw NetworkError.invalidURL }
        guard let url = URL(string: "\(base.absoluteString)/transmission/rpc") else {
            throw NetworkError.invalidURL
        }
        return url
    }

    func fetchTorrents(_ config: ServerConfig) async throws -> [TransmissionTorrent] {
        let body: [String: Any] = [
            "method": "torrent-get",
            "arguments": ["fields": torrentFields]
        ]
        let response: TransmissionRPCResponse = try await rpcRequest(config, body: body)
        return response.arguments?.torrents ?? []
    }

    func fetchTorrentDetail(_ config: ServerConfig, id: Int) async throws -> TransmissionTorrent? {
        let body: [String: Any] = [
            "method": "torrent-get",
            "arguments": ["fields": detailFields, "ids": [id]]
        ]
        let response: TransmissionRPCResponse = try await rpcRequest(config, body: body)
        return response.arguments?.torrents?.first
    }

    func startTorrent(_ config: ServerConfig, ids: [Int]) async throws {
        let body: [String: Any] = [
            "method": "torrent-start",
            "arguments": ["ids": ids]
        ]
        let _: TransmissionRPCResponse = try await rpcRequest(config, body: body)
    }

    func stopTorrent(_ config: ServerConfig, ids: [Int]) async throws {
        let body: [String: Any] = [
            "method": "torrent-stop",
            "arguments": ["ids": ids]
        ]
        let _: TransmissionRPCResponse = try await rpcRequest(config, body: body)
    }

    func removeTorrent(_ config: ServerConfig, ids: [Int], deleteData: Bool = false) async throws {
        let body: [String: Any] = [
            "method": "torrent-remove",
            "arguments": ["ids": ids, "delete-local-data": deleteData]
        ]
        let _: TransmissionRPCResponse = try await rpcRequest(config, body: body)
    }

    func addTorrent(_ config: ServerConfig, url: String, downloadDir: String? = nil) async throws {
        var args: [String: Any] = ["filename": url]
        if let downloadDir {
            args["download-dir"] = downloadDir
        }
        let body: [String: Any] = [
            "method": "torrent-add",
            "arguments": args
        ]
        let _: TransmissionRPCResponse = try await rpcRequest(config, body: body)
    }

    func addTorrentFile(_ config: ServerConfig, data: Data, downloadDir: String? = nil) async throws {
        var args: [String: Any] = ["metainfo": data.base64EncodedString()]
        if let downloadDir {
            args["download-dir"] = downloadDir
        }
        let body: [String: Any] = [
            "method": "torrent-add",
            "arguments": args
        ]
        let _: TransmissionRPCResponse = try await rpcRequest(config, body: body)
    }

    func verifyTorrent(_ config: ServerConfig, ids: [Int]) async throws {
        let body: [String: Any] = [
            "method": "torrent-verify",
            "arguments": ["ids": ids]
        ]
        let _: TransmissionRPCResponse = try await rpcRequest(config, body: body)
    }

    func fetchSession(_ config: ServerConfig) async throws -> TransmissionSession {
        let body: [String: Any] = ["method": "session-get"]
        let response: TransmissionSessionRPCResponse = try await rpcRequest(config, body: body)
        guard let session = response.arguments else { throw NetworkError.invalidResponse }
        return session
    }

    func fetchSessionStats(_ config: ServerConfig) async throws -> TransmissionSessionStats {
        let body: [String: Any] = ["method": "session-stats"]
        let response: TransmissionSessionStatsResponse = try await rpcRequest(config, body: body)
        guard let stats = response.arguments else { throw NetworkError.invalidResponse }
        return stats
    }

    func setAltSpeedEnabled(_ config: ServerConfig, enabled: Bool) async throws {
        let body: [String: Any] = [
            "method": "session-set",
            "arguments": ["alt-speed-enabled": enabled]
        ]
        let _: TransmissionSessionRPCResponse = try await rpcRequest(config, body: body)
    }

    func setTrackerList(_ config: ServerConfig, id: Int, trackerList: String) async throws {
        let body: [String: Any] = [
            "method": "torrent-set",
            "arguments": ["ids": [id], "trackerList": trackerList]
        ]
        let _: TransmissionRPCResponse = try await rpcRequest(config, body: body)
    }

    func removeTracker(_ config: ServerConfig, id: Int, trackerId: Int) async throws {
        let body: [String: Any] = [
            "method": "torrent-set",
            "arguments": ["ids": [id], "trackerRemove": [trackerId]]
        ]
        let _: TransmissionRPCResponse = try await rpcRequest(config, body: body)
    }

    func setTorrentPriority(_ config: ServerConfig, id: Int, priority: Int) async throws {
        let body: [String: Any] = [
            "method": "torrent-set",
            "arguments": ["ids": [id], "bandwidthPriority": priority]
        ]
        let _: TransmissionRPCResponse = try await rpcRequest(config, body: body)
    }

    func setFilePriority(_ config: ServerConfig, id: Int, fileIndices: [Int], priority: Int) async throws {
        let key: String
        switch priority {
        case 1:  key = "priority-high"
        case -1: key = "priority-low"
        default: key = "priority-normal"
        }
        let body: [String: Any] = [
            "method": "torrent-set",
            "arguments": ["ids": [id], key: fileIndices]
        ]
        let _: TransmissionRPCResponse = try await rpcRequest(config, body: body)
    }

    func setFilesWanted(_ config: ServerConfig, id: Int, fileIndices: [Int], wanted: Bool) async throws {
        let key = wanted ? "files-wanted" : "files-unwanted"
        let body: [String: Any] = [
            "method": "torrent-set",
            "arguments": ["ids": [id], key: fileIndices]
        ]
        let _: TransmissionRPCResponse = try await rpcRequest(config, body: body)
    }

    func setTorrentSpeedLimitEnabled(_ config: ServerConfig, id: Int, download: Bool, enabled: Bool) async throws {
        let key = download ? "speed-limit-down-enabled" : "speed-limit-up-enabled"
        let body: [String: Any] = [
            "method": "torrent-set",
            "arguments": ["ids": [id], key: enabled]
        ]
        let _: TransmissionRPCResponse = try await rpcRequest(config, body: body)
    }

    func setTorrentSpeedLimitValue(_ config: ServerConfig, id: Int, download: Bool, limit: Int) async throws {
        let key = download ? "speed-limit-down" : "speed-limit-up"
        let enabledKey = download ? "speed-limit-down-enabled" : "speed-limit-up-enabled"
        let body: [String: Any] = [
            "method": "torrent-set",
            "arguments": ["ids": [id], key: limit, enabledKey: true]
        ]
        let _: TransmissionRPCResponse = try await rpcRequest(config, body: body)
    }

    func setTorrentPeerLimit(_ config: ServerConfig, id: Int, limit: Int) async throws {
        let body: [String: Any] = [
            "method": "torrent-set",
            "arguments": ["ids": [id], "peer-limit": limit]
        ]
        let _: TransmissionRPCResponse = try await rpcRequest(config, body: body)
    }

    func setTorrentSeedRatio(_ config: ServerConfig, id: Int, mode: Int, limit: Double) async throws {
        let body: [String: Any] = [
            "method": "torrent-set",
            "arguments": ["ids": [id], "seedRatioMode": mode, "seedRatioLimit": limit]
        ]
        let _: TransmissionRPCResponse = try await rpcRequest(config, body: body)
    }

    func setTorrentSeedIdle(_ config: ServerConfig, id: Int, mode: Int, limit: Int) async throws {
        let body: [String: Any] = [
            "method": "torrent-set",
            "arguments": ["ids": [id], "seedIdleMode": mode, "seedIdleLimit": limit]
        ]
        let _: TransmissionRPCResponse = try await rpcRequest(config, body: body)
    }

    func setTorrentLocation(_ config: ServerConfig, id: Int, location: String, move: Bool) async throws {
        let body: [String: Any] = [
            "method": "torrent-set-location",
            "arguments": ["ids": [id], "location": location, "move": move]
        ]
        let _: TransmissionRPCResponse = try await rpcRequest(config, body: body)
    }

    func setTorrentLabels(_ config: ServerConfig, id: Int, labels: [String]) async throws {
        let body: [String: Any] = [
            "method": "torrent-set",
            "arguments": ["ids": [id], "labels": labels]
        ]
        let _: TransmissionRPCResponse = try await rpcRequest(config, body: body)
    }

    func moveTorrentQueue(_ config: ServerConfig, id: Int, direction: QueueDirection) async throws {
        let method: String
        switch direction {
        case .top:    method = "queue-move-top"
        case .up:     method = "queue-move-up"
        case .down:   method = "queue-move-down"
        case .bottom: method = "queue-move-bottom"
        }
        let body: [String: Any] = [
            "method": method,
            "arguments": ["ids": [id]]
        ]
        let _: TransmissionRPCResponse = try await rpcRequest(config, body: body)
    }

    func reannounce(_ config: ServerConfig, ids: [Int]) async throws {
        let body: [String: Any] = [
            "method": "torrent-reannounce",
            "arguments": ["ids": ids]
        ]
        let _: TransmissionRPCResponse = try await rpcRequest(config, body: body)
    }

    private func rpcRequest<T: Decodable>(_ config: ServerConfig, body: [String: Any]) async throws -> T {
        let url = try rpcURL(config)
        let jsonData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if !config.apiKey.isEmpty {
            let credentials = config.apiKey
            if let data = credentials.data(using: .utf8) {
                request.setValue("Basic \(data.base64EncodedString())", forHTTPHeaderField: "Authorization")
            }
        }

        if !sessionId.isEmpty {
            request.setValue(sessionId, forHTTPHeaderField: "X-Transmission-Session-Id")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 409 {
            if let newSessionId = httpResponse.value(forHTTPHeaderField: "X-Transmission-Session-Id") {
                sessionId = newSessionId
                return try await rpcRequest(config, body: body)
            }
        }

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}
