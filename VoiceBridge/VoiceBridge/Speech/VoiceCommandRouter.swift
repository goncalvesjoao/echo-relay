import Foundation

// MARK: - VoiceCommand

enum VoiceCommand: String, CaseIterable {
    case stop   = "stop"
    case pause  = "pause"
    case resume = "resume"
    case skip   = "skip"
    case reread = "reread"
    case done   = "done"
}

// MARK: - VoiceCommandRouter

/// Inspects each transcript word/phrase and either fires a known voice
/// command or forwards the text to the keyboard simulator as plain input.
final class VoiceCommandRouter {

    // MARK: Dependencies (injected)

    var ttsEngine: TTSEngine?
    var speechInputManager: SpeechInputManager?
    var keyboardSimulator: KeyboardSimulator?

    // MARK: Configuration

    /// Words that are stripped before deciding to forward as plain text.
    private let knownCommandWords: Set<String> = Set(VoiceCommand.allCases.map { $0.rawValue })

    // MARK: Public API

    /// Called with each incremental transcript. `isFinal` marks the last segment.
    func route(transcript: String, isFinal: Bool) {
        guard isFinal else { return }  // act only on final segments to avoid mid-word matches

        let words = transcript
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        // Check if the entire transcript is a single recognized command.
        if words.count == 1, let command = VoiceCommand(rawValue: words[0]) {
            handle(command: command)
            return
        }

        // Multi-word: strip leading commands, then forward remaining text.
        var remaining = words
        if let first = remaining.first, let command = VoiceCommand(rawValue: first) {
            handle(command: command)
            remaining.removeFirst()
        }

        let plainText = remaining
            .filter { !knownCommandWords.contains($0) }
            .joined(separator: " ")

        if !plainText.isEmpty {
            keyboardSimulator?.type(plainText + " ")
        }
    }

    // MARK: Private command dispatch

    private func handle(command: VoiceCommand) {
        switch command {
        case .stop:
            ttsEngine?.stop()
            speechInputManager?.stopListening()
        case .pause:
            ttsEngine?.pause()
        case .resume:
            ttsEngine?.resume()
        case .skip:
            ttsEngine?.skip()
        case .reread:
            ttsEngine?.reread()
        case .done:
            speechInputManager?.stopListening()
        }
    }
}
