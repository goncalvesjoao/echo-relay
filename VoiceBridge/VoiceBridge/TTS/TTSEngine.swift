import AVFoundation
import Foundation

// MARK: - TTSEngine

/// Wraps AVSpeechSynthesizer, providing a queueable interface with
/// pause, resume, skip, reread and stop controls.
final class TTSEngine: NSObject {

    // MARK: Callbacks

    var onStateChange: ((TTSState) -> Void)?

    // MARK: State

    private(set) var state: TTSState = .idle {
        didSet { onStateChange?(state) }
    }

    // MARK: Configuration

    /// Maximum number of past utterances to repeat with `reread()`.
    private let rereadSentenceCount = 3

    // MARK: Private

    private let synthesizer = AVSpeechSynthesizer()
    private var utteranceQueue: [AVSpeechUtterance] = []
    /// Raw strings corresponding to queued utterances (used for reread).
    private var stringQueue: [String] = []
    private var lastSpokenStrings: [String] = []

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: Public API

    func speak(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let utterance = makeUtterance(text)
        utteranceQueue.append(utterance)
        stringQueue.append(text)

        if state == .idle {
            playNextIfAvailable()
        }
    }

    func pause() {
        guard state == .speaking else { return }
        synthesizer.pauseSpeaking(at: .word)
        state = .paused
    }

    func resume() {
        guard state == .paused else { return }
        synthesizer.continueSpeaking()
        state = .speaking
    }

    func skip() {
        synthesizer.stopSpeaking(at: .word)
        // delegate will call playNextIfAvailable
    }

    func stop() {
        utteranceQueue.removeAll()
        stringQueue.removeAll()
        synthesizer.stopSpeaking(at: .immediate)
        state = .idle
    }

    /// Re-speaks the most recent utterances (up to `rereadSentenceCount` sentences).
    func reread() {
        let toReread = lastSpokenStrings.suffix(rereadSentenceCount)
        guard !toReread.isEmpty else { return }
        stop()
        toReread.forEach { speak($0) }
    }

    // MARK: Private helpers

    private func makeUtterance(_ text: String) -> AVSpeechUtterance {
        let u = AVSpeechUtterance(string: text)
        u.rate = UserPreferences.shared.ttsRate
        let voiceID = UserPreferences.shared.ttsVoiceIdentifier
        if !voiceID.isEmpty {
            u.voice = AVSpeechSynthesisVoice(identifier: voiceID)
        }
        return u
    }

    private func playNextIfAvailable() {
        guard !utteranceQueue.isEmpty else {
            state = .idle
            return
        }
        let utterance = utteranceQueue.removeFirst()
        let text = stringQueue.removeFirst()
        lastSpokenStrings.append(text)
        if lastSpokenStrings.count > 10 { lastSpokenStrings.removeFirst() }
        state = .speaking
        synthesizer.speak(utterance)
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension TTSEngine: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didFinish utterance: AVSpeechUtterance) {
        playNextIfAvailable()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didCancel utterance: AVSpeechUtterance) {
        playNextIfAvailable()
    }
}

// MARK: - TTSState

enum TTSState {
    case idle
    case speaking
    case paused
}
