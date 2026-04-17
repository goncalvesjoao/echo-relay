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

        scheduleCharacter(at: 0, chars: chars, source: source)
    }

    // MARK: Private helpers

    private func scheduleCharacter(at index: Int, chars: [Character], source: CGEventSource?) {
        guard index < chars.count else { return }

        let delay = interKeyDelay * Double(index)
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + delay) {
            self.injectCharacter(chars[index], source: source)
            // Schedule remaining characters recursively to avoid blocking
            if index + 1 < chars.count {
                self.scheduleCharacter(at: index + 1, chars: chars, source: source)
            }
        }
    }

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
