import AppKit
import Foundation

// MARK: - HUDWindow

/// A borderless, always-on-top, semi-transparent floating panel that shows
/// the live transcription and TTS status.
final class HUDWindow: NSPanel {

    // MARK: Subviews

    private let transcriptLabel = NSTextField(labelWithString: "")
    private let statusLabel     = NSTextField(labelWithString: "")
    private let backgroundView  = NSVisualEffectView()

    // MARK: Init

    init() {
        let frame = NSRect(x: 0, y: 0, width: 420, height: 90)
        super.init(
            contentRect: frame,
            styleMask: [.nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )

        isReleasedWhenClosed = false
        level = .floating
        hasShadow = true
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        setupUI(frame: frame)
        center()
        // Restore saved position if any
        if let saved = UserPreferences.shared.defaults_hudOrigin {
            setFrameOrigin(saved)
        }
    }

    // MARK: Public API

    func updateTranscript(_ text: String) {
        DispatchQueue.main.async {
            self.transcriptLabel.stringValue = text.isEmpty ? "" : "🎙 \(text)"
        }
    }

    func updateStatus(_ text: String) {
        DispatchQueue.main.async {
            self.statusLabel.stringValue = text
        }
    }

    func show() {
        orderFrontRegardless()
    }

    func hide() {
        orderOut(nil)
    }

    // MARK: Private layout

    private func setupUI(frame: NSRect) {
        // Background blur — use popover material for a nice frosted glass look
        backgroundView.material = .popover
        backgroundView.blendingMode = .behindWindow
        backgroundView.state = .active
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = 12
        backgroundView.layer?.masksToBounds = true
        backgroundView.frame = NSRect(x: 0, y: 0, width: frame.width, height: frame.height)
        contentView?.addSubview(backgroundView)

        // Transcript label
        transcriptLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        transcriptLabel.textColor = .labelColor
        transcriptLabel.lineBreakMode = .byTruncatingTail
        transcriptLabel.frame = NSRect(x: 12, y: 44, width: frame.width - 24, height: 32)
        backgroundView.addSubview(transcriptLabel)

        // Status label
        statusLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.frame = NSRect(x: 12, y: 14, width: frame.width - 24, height: 20)
        backgroundView.addSubview(statusLabel)
    }

    // MARK: Save position on move

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        UserPreferences.shared.defaults_hudOrigin = frame.origin
    }
}

// MARK: - UserPreferences + HUD position helpers

private extension UserPreferences {
    var defaults_hudOrigin: NSPoint? {
        get {
            guard UserDefaults.standard.bool(forKey: "hudPositionSaved") else { return nil }
            let x = UserDefaults.standard.double(forKey: "hudOriginX")
            let y = UserDefaults.standard.double(forKey: "hudOriginY")
            return NSPoint(x: x, y: y)
        }
        set {
            if let p = newValue {
                UserDefaults.standard.set(true,  forKey: "hudPositionSaved")
                UserDefaults.standard.set(p.x,   forKey: "hudOriginX")
                UserDefaults.standard.set(p.y,   forKey: "hudOriginY")
            } else {
                UserDefaults.standard.removeObject(forKey: "hudPositionSaved")
            }
        }
    }
}
