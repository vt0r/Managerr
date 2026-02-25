import Foundation

nonisolated enum FormatUtils {
    static func fileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    static func speed(_ bytesPerSecond: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: bytesPerSecond))/s"
    }

    static func eta(_ seconds: Int?) -> String {
        guard let seconds, seconds > 0 else { return "—" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    static func percentage(_ value: Double?) -> String {
        guard let value else { return "0%" }
        return "\(Int(value * 100))%"
    }

    static func trackDuration(_ milliseconds: Int?) -> String {
        guard let ms = milliseconds, ms > 0 else { return "—" }
        let totalSeconds = ms / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
