import Foundation

public enum GBFormat {
    private static let bytesPerGB = 1_000_000_000.0

    public static func string(bytes: Double) -> String {
        let gigabytes = max(0, bytes) / bytesPerGB
        return String(format: gigabytes < 1 ? "%.2f" : "%.1f", gigabytes)
    }

    public static func bytes(from text: String) -> Double? {
        let normalized = text
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard let gigabytes = Double(normalized), gigabytes.isFinite, gigabytes >= 0 else { return nil }
        return gigabytes * bytesPerGB
    }
}
