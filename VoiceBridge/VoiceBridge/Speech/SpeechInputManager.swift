import Speech
import AVFoundation
import Foundation

// MARK: - SpeechInputManager

/// Wraps SFSpeechRecognizer + AVAudioEngine to deliver live transcripts.
final class SpeechInputManager: NSObject {

    // MARK: Callbacks

    /// Called with each partial / final transcript string.
    var onTranscript: ((String, Bool) -> Void)?
    /// Called when the recognizer state changes.
    var onStateChange: ((SpeechInputState) -> Void)?

    // MARK: State

    private(set) var state: SpeechInputState = .idle {
        didSet { onStateChange?(state) }
    }

    // MARK: Private

    private let recognizer: SFSpeechRecognizer? = {
        SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let queue = DispatchQueue(label: "com.voicebridge.speech", qos: .userInteractive)

    // MARK: Public API

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async { completion(status == .authorized) }
        }
    }

    func startListening() {
        guard state == .idle else { return }
        state = .starting

        queue.async { [weak self] in
            self?.startRecognition()
        }
    }

    func stopListening() {
        guard state == .listening || state == .starting else { return }
        state = .stopping

        queue.async { [weak self] in
            self?.stopRecognition()
        }
    }

    func toggleListening() {
        if state == .idle {
            startListening()
        } else {
            stopListening()
        }
    }

    // MARK: Private recognition helpers

    private func startRecognition() {
        guard let recognizer = recognizer, recognizer.isAvailable else {
            DispatchQueue.main.async { self.state = .idle }
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("[SpeechInputManager] Audio engine failed to start: \(error)")
            DispatchQueue.main.async { self.state = .idle }
            return
        }

        DispatchQueue.main.async { self.state = .listening }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.onTranscript?(text, result.isFinal)
                }
            }

            if error != nil || result?.isFinal == true {
                DispatchQueue.main.async {
                    if self.state != .stopping { self.state = .idle }
                }
                self.stopRecognition()
            }
        }
    }

    private func stopRecognition() {
        recognitionRequest?.endAudio()
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        DispatchQueue.main.async { self.state = .idle }
    }
}

// MARK: - State

enum SpeechInputState {
    case idle
    case starting
    case listening
    case stopping
}
