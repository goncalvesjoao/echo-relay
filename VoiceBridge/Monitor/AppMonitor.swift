import ApplicationServices
import AppKit
import Foundation

// MARK: - AppMonitor

/// Polls the frontmost application's accessibility tree and fires
/// `onNewContent` when paragraph-length text appears in the content area.
final class AppMonitor {

    // MARK: Callbacks

    /// Fired on the main queue when new content text is detected.
    var onNewContent: ((String) -> Void)?

    // MARK: Configuration

    var pollInterval: TimeInterval = 0.5

    // MARK: Private state

    private var timer: Timer?
    /// Maps bundle-identifier → last-seen content snapshot.
    private var snapshots: [String: String] = [:]

    // MARK: Public API

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval,
                                     repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: Private polling

    private func poll() {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleID = frontApp.bundleIdentifier else { return }

        // Skip denied apps
        if UserPreferences.shared.deniedApps.contains(bundleID) { return }

        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
        guard let contentText = extractContentText(from: appElement) else { return }

        let previous = snapshots[bundleID] ?? ""
        if contentText != previous {
            let newText = findAddedText(old: previous, new: contentText)
            if !newText.isEmpty {
                DispatchQueue.main.async { self.onNewContent?(newText) }
            }
            snapshots[bundleID] = contentText
        }
    }

    // MARK: AX traversal

    /// Recursively walks the AX tree and returns the concatenated value of
    /// "content-like" text nodes (ignoring timestamps and short UI labels).
    private func extractContentText(from element: AXUIElement) -> String? {
        var role: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        let roleStr = role as? String ?? ""

        // Descend into scrollable areas and groups that look like chat / output panes.
        var children: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        let childList = children as? [AXUIElement] ?? []

        var parts: [String] = []

        for child in childList {
            if let text = extractContentText(from: child) {
                parts.append(text)
            }
        }

        // Leaf nodes: capture their value if they look like content text.
        if childList.isEmpty || roleStr == kAXStaticTextRole as String {
            var value: AnyObject?
            AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
            if let str = value as? String, isContentLike(str) {
                return str
            }
        }

        return parts.isEmpty ? nil : parts.joined(separator: "\n")
    }

    private static let timestampPattern = #"^\d{1,2}:\d{2}(:\d{2})?( [AP]M)?$"#

    /// Simple heuristic: content-like text is at least 20 characters long,
    /// is not pure whitespace, and does not look like a single-word label or timestamp.
    private func isContentLike(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 20 else { return false }
        if trimmed.range(of: AppMonitor.timestampPattern, options: .regularExpression) != nil { return false }
        return true
    }

    // MARK: Diff helper

    /// Returns text that is present in `new` but absent in `old`.
    private func findAddedText(old: String, new: String) -> String {
        guard !old.isEmpty else { return new }
        if new.hasPrefix(old) {
            let added = String(new.dropFirst(old.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return added
        }
        // Fallback: return whole new string (content was replaced / truncated)
        return new
    }
}
