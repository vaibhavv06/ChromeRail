import Foundation

struct LogitechShortcutProbe: Codable {
    let generatedAt: Date
    let eventType: UInt32
    let keyCode: Int64
    let sourceProcessIdentifier: Int32
    let sourceBundleIdentifier: String?
    let sourceMatchedLogitech: Bool
    let pointerInsideVerticalTabs: Bool
    let intercepted: Bool
}

enum DiagnosticsStore {
    private static var lastFingerprint: String?
    private static var lastShortcutFingerprint: String?

    static var reportURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("ChromeRail", isDirectory: true)
            .appendingPathComponent("probe.json")
    }

    static func writeIfChanged(_ report: ChromeProbeReport) {
        let fingerprint = makeFingerprint(report)
        guard fingerprint != lastFingerprint else { return }
        do {
            let directory = reportURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(report).write(to: reportURL, options: .atomic)
            lastFingerprint = fingerprint
        } catch {
            NSLog("ChromeRail diagnostic write failed: \(error)")
        }
    }

    static func writeShortcutIfChanged(_ probe: LogitechShortcutProbe) {
        let fingerprint = "\(probe.eventType)|\(probe.keyCode)|\(probe.sourceProcessIdentifier)|\(probe.sourceBundleIdentifier ?? "-")|\(probe.sourceMatchedLogitech)|\(probe.pointerInsideVerticalTabs)|\(probe.intercepted)"
        guard fingerprint != lastShortcutFingerprint else { return }
        do {
            let url = reportURL.deletingLastPathComponent().appendingPathComponent("logitech-shortcut.json")
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(probe).write(to: url, options: .atomic)
            lastShortcutFingerprint = fingerprint
        } catch {
            NSLog("ChromeRail shortcut diagnostic write failed: \(error)")
        }
    }

    private static func makeFingerprint(_ report: ChromeProbeReport) -> String {
        let windows = report.windows.map { window in
            "\(window.index):\(window.isFocused):\(window.isMinimized):\(window.hasVerticalTabs)"
        }.joined(separator: ";")
        return "\(report.chromeVersion)|\(report.gestureTapAvailable)|\(windows)"
    }
}
