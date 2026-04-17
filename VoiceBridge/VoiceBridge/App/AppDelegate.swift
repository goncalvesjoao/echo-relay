import AppKit
import Foundation

// MARK: - AppDelegate

@NSApplicationMain
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: Components

    private let hotKeyManager     = HotKeyManager()
    private let speechInput       = SpeechInputManager()
    private let keyboardSim       = KeyboardSimulator()
    private let commandRouter     = VoiceCommandRouter()
    private let ttsEngine         = TTSEngine()
    private let appMonitor        = AppMonitor()
    private var menuBarController: MenuBarController!
    private var hudWindow: HUDWindow!
    private var settingsController: SettingsWindowController!

    // MARK: NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Suppress dock icon (LSUIElement = YES handles this, but set here too as a safeguard)
        NSApp.setActivationPolicy(.accessory)

        // Wire up all components
        setupComponents()

        // Request speech-recognition authorisation before the user first uses it
        speechInput.requestAuthorization { granted in
            if !granted {
                self.showAlert(title: "Speech Recognition Unavailable",
                               message: "Grant access in System Settings → Privacy → Speech Recognition.")
            }
        }

        // Start monitoring apps for AI responses
        appMonitor.start()

        // Install global hotkey
        hotKeyManager.hotKey = UserPreferences.shared.hotKey
        hotKeyManager.start()

        // Show HUD
        hudWindow.show()
        hudWindow.updateStatus("Idle — press \(hotKeyLabel()) to start")
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyManager.stop()
        speechInput.stopListening()
        appMonitor.stop()
        ttsEngine.stop()
    }

    // MARK: Wiring

    private func setupComponents() {
        // HUD
        hudWindow = HUDWindow()

        // Menu bar
        menuBarController = MenuBarController()
        menuBarController.onSettings = { [weak self] in self?.showSettings() }
        menuBarController.onPauseAll = { [weak self] in self?.pauseAll() }
        menuBarController.onQuit     = { NSApp.terminate(nil) }

        // Settings
        settingsController = SettingsWindowController()

        // Voice command router has references to other components
        commandRouter.ttsEngine          = ttsEngine
        commandRouter.speechInputManager = speechInput
        commandRouter.keyboardSimulator  = keyboardSim

        // Speech input → HUD, command router, menu bar icon
        speechInput.onTranscript = { [weak self] transcript, isFinal in
            guard let self = self else { return }
            self.hudWindow.updateTranscript(transcript)
            self.commandRouter.route(transcript: transcript, isFinal: isFinal)
            if isFinal {
                // Clear transcript after a short delay so the user can read it
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.hudWindow.updateTranscript("")
                }
            }
        }

        speechInput.onStateChange = { [weak self] state in
            guard let self = self else { return }
            let listening = (state == .listening)
            self.menuBarController.setListening(listening)
            self.hudWindow.updateStatus(listening ? "Listening…" : "Idle — press \(self.hotKeyLabel()) to start")
        }

        // App monitor → TTS
        appMonitor.onNewContent = { [weak self] text in
            self?.ttsEngine.speak(text)
        }

        // TTS → menu bar icon
        ttsEngine.onStateChange = { [weak self] state in
            let active = (state == .speaking)
            self?.menuBarController.setTTSActive(active)
            self?.hudWindow.updateStatus(active ? "Speaking…" : "Idle")
        }

        // Hot key → toggle listening
        hotKeyManager.onToggle = { [weak self] in
            self?.speechInput.toggleListening()
        }
    }

    // MARK: Actions

    private func pauseAll() {
        ttsEngine.pause()
        speechInput.stopListening()
    }

    private func showSettings() {
        settingsController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: Helpers

    private func hotKeyLabel() -> String {
        let combo = UserPreferences.shared.hotKey
        var parts: [String] = []
        let flags = combo.eventFlags
        if flags.contains(.maskControl)   { parts.append("⌃") }
        if flags.contains(.maskAlternate) { parts.append("⌥") }
        if flags.contains(.maskShift)     { parts.append("⇧") }
        if flags.contains(.maskCommand)   { parts.append("⌘") }
        parts.append("D")
        return parts.joined()
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
