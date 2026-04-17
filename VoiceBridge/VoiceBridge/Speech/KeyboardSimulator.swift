import CoreGraphics
import Foundation

// MARK: - KeyboardSimulator

/// Injects text as synthetic keystrokes into the currently focused application.
final class KeyboardSimulator {

    // MARK: Configuration

    /// Delay between successive characters to mimic human typing (seconds).
    var interKeyDelay: TimeInterval = 0.02

    // MARK: Public API

    /// Asynchronously types `text` into the focused app, character by character.
    func type(_ text: String) {
        guard !text.isEmpty else { return }

        let source = CGEventSource(stateID: .hidSystemState)
        let chars = Array(text)

        DispatchQueue.global(qos: .userInteractive).async {
            for char in chars {
                self.injectCharacter(char, source: source)
                if self.interKeyDelay > 0 {
                    Thread.sleep(forTimeInterval: self.interKeyDelay)
                }
            }
        }
    }

    // MARK: Private helpers

    private func injectCharacter(_ char: Character, source: CGEventSource?) {
        // CGEvent requires a UTF-16 code unit array
        var utf16 = Array(String(char).utf16)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let keyUp   = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
            return
        }

        keyDown.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
        keyUp.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)

        keyDown.post(tap: .cgSessionEventTap)
        keyUp.post(tap: .cgSessionEventTap)
    }
}
