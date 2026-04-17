import AppKit
import Foundation

// MARK: - MenuBarController

/// Manages the NSStatusItem (menu bar icon) and its dropdown menu.
final class MenuBarController {

    // MARK: Dependencies (set by AppDelegate)

    var onSettings: (() -> Void)?
    var onPauseAll: (() -> Void)?
    var onQuit: (() -> Void)?

    // MARK: Private

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var isListening = false
    private var isTTSActive = false

    // MARK: Init

    init() {
        setupButton()
        buildMenu()
    }

    // MARK: Public API

    func setListening(_ listening: Bool) {
        isListening = listening
        updateIcon()
    }

    func setTTSActive(_ active: Bool) {
        isTTSActive = active
        updateIcon()
    }

    // MARK: Private helpers

    private func setupButton() {
        guard let button = statusItem.button else { return }
        button.toolTip = "EchoRelay"
        updateIcon()
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        let symbolName: String
        if isListening {
            symbolName = "mic.fill"
        } else if isTTSActive {
            symbolName = "speaker.wave.2.fill"
        } else {
            symbolName = "mic"
        }
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
            image.isTemplate = true
            button.image = image
        }
    }

    private func buildMenu() {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(title: "Settings…",
                                      action: #selector(settingsTapped),
                                      keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let pauseItem = NSMenuItem(title: "Pause All",
                                   action: #selector(pauseAllTapped),
                                   keyEquivalent: "")
        pauseItem.target = self
        menu.addItem(pauseItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit EchoRelay",
                                  action: #selector(quitTapped),
                                  keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func settingsTapped() { onSettings?() }
    @objc private func pauseAllTapped() { onPauseAll?() }
    @objc private func quitTapped()     { onQuit?() }
}
