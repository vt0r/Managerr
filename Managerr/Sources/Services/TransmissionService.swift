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
        "magnetLink"
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
