import AppKit
import AVFoundation
import Foundation

// MARK: - SettingsWindowController

/// A simple settings panel: hotkey field, TTS voice picker, TTS rate slider,
/// and app denylist text field.
final class SettingsWindowController: NSWindowController {

    // MARK: Subviews

    private var hotkeyField    = NSTextField()
    private var voicePopUp     = NSPopUpButton()
    private var rateSlider     = NSSlider()
    private var denylistView   = NSTextView()
    private var rateLabel      = NSTextField(labelWithString: "")

    // MARK: Init

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "EchoRelay Settings"
        window.isReleasedWhenClosed = false
        self.init(window: window)
        buildUI()
        loadValues()
    }

    override func showWindow(_ sender: Any?) {
        loadValues()
        super.showWindow(sender)
        window?.center()
    }

    // MARK: UI construction

    private func buildUI() {
        guard let content = window?.contentView else { return }
        let width: CGFloat = 440

        // ── Hotkey ────────────────────────────────────────────────────────────
        addLabel("Global Hotkey", x: 20, y: 248, width: 140, in: content)

        hotkeyField.frame = NSRect(x: 170, y: 244, width: 250, height: 24)
        hotkeyField.placeholderString = "e.g. Control+D"
        content.addSubview(hotkeyField)

        // ── TTS Voice ─────────────────────────────────────────────────────────
        addLabel("TTS Voice", x: 20, y: 204, width: 140, in: content)

        voicePopUp.frame = NSRect(x: 170, y: 200, width: 250, height: 24)
        populateVoices()
        content.addSubview(voicePopUp)

        // ── TTS Rate ──────────────────────────────────────────────────────────
        addLabel("Speech Rate", x: 20, y: 160, width: 140, in: content)

        rateSlider.frame = NSRect(x: 170, y: 156, width: 190, height: 24)
        rateSlider.minValue = Double(AVSpeechUtteranceMinimumSpeechRate)
        rateSlider.maxValue = Double(AVSpeechUtteranceMaximumSpeechRate)
        rateSlider.target = self
        rateSlider.action = #selector(rateChanged)
        content.addSubview(rateSlider)

        rateLabel.frame = NSRect(x: 370, y: 156, width: 50, height: 24)
        content.addSubview(rateLabel)

        // ── Denylist ──────────────────────────────────────────────────────────
        addLabel("Skip Apps\n(bundle IDs,\ncomma-separated)", x: 20, y: 90, width: 140, in: content)

        let scrollView = NSScrollView(frame: NSRect(x: 170, y: 92, width: 250, height: 60))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder

        denylistView.frame = NSRect(x: 0, y: 0, width: scrollView.contentSize.width,
                                    height: scrollView.contentSize.height)
        denylistView.isEditable = true
        denylistView.isRichText = false
        denylistView.font = NSFont.systemFont(ofSize: 12)
        denylistView.autoresizingMask = [.width]

        scrollView.documentView = denylistView
        content.addSubview(scrollView)

        // ── Save button ───────────────────────────────────────────────────────
        let saveBtn = NSButton(title: "Save", target: self, action: #selector(save))
        saveBtn.frame = NSRect(x: width - 100, y: 20, width: 80, height: 32)
        saveBtn.bezelStyle = .rounded
        saveBtn.keyEquivalent = "\r"
        content.addSubview(saveBtn)
    }

    // MARK: Load / save

    private func loadValues() {
        let prefs = UserPreferences.shared
        hotkeyField.stringValue = hotKeyString(from: prefs.hotKey)
        rateSlider.floatValue   = prefs.ttsRate
        updateRateLabel()
        denylistView.string = prefs.deniedApps.joined(separator: ", ")

        let currentVoice = prefs.ttsVoiceIdentifier
        if !currentVoice.isEmpty, let item = voicePopUp.item(withTitle: voiceDisplayName(currentVoice)) {
            voicePopUp.select(item)
        }
    }

    @objc private func save() {
        let prefs = UserPreferences.shared
        prefs.ttsRate = rateSlider.floatValue

        if let selected = voicePopUp.selectedItem?.representedObject as? String {
            prefs.ttsVoiceIdentifier = selected
        }

        let rawList = denylistView.string
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        prefs.deniedApps = rawList

        window?.close()
    }

    // MARK: Helpers

    @objc private func rateChanged() { updateRateLabel() }

    private func updateRateLabel() {
        rateLabel.stringValue = String(format: "%.2f", rateSlider.floatValue)
    }

    private func populateVoices() {
        voicePopUp.removeAllItems()
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted { $0.name < $1.name }
        for voice in voices {
            let item = NSMenuItem(title: voiceDisplayName(voice.identifier),
                                  action: nil,
                                  keyEquivalent: "")
            item.representedObject = voice.identifier
            voicePopUp.menu?.addItem(item)
        }
    }

    private func voiceDisplayName(_ identifier: String) -> String {
        AVSpeechSynthesisVoice(identifier: identifier)?.name ?? identifier
    }

    private func hotKeyString(from combo: KeyCombo) -> String {
        var parts: [String] = []
        let flags = combo.eventFlags
        if flags.contains(.maskControl)   { parts.append("Control") }
        if flags.contains(.maskAlternate) { parts.append("Option") }
        if flags.contains(.maskShift)     { parts.append("Shift") }
        if flags.contains(.maskCommand)   { parts.append("Command") }
        // Append the key character using keyCode 2 → "d"
        let keyChar: String
        switch combo.keyCode {
        case 0:  keyChar = "a"
        case 1:  keyChar = "s"
        case 2:  keyChar = "d"
        case 3:  keyChar = "f"
        case 4:  keyChar = "h"
        case 5:  keyChar = "g"
        case 6:  keyChar = "z"
        case 7:  keyChar = "x"
        case 8:  keyChar = "c"
        case 9:  keyChar = "v"
        default: keyChar = "key\(combo.keyCode)"
        }
        parts.append(keyChar.uppercased())
        return parts.joined(separator: "+")
    }

    @discardableResult
    private func addLabel(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat,
                           in view: NSView) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.frame = NSRect(x: x, y: y, width: width, height: 40)
        label.alignment = .right
        label.font = NSFont.systemFont(ofSize: 12)
        view.addSubview(label)
        return label
    }
}
