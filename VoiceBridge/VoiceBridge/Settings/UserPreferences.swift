import Foundation
import CoreGraphics
import AVFoundation

// MARK: - KeyCombo

struct KeyCombo: Codable, Equatable {
    /// Virtual key code (e.g. 2 = "d" on US keyboards)
    var keyCode: CGKeyCode
    /// CGEventFlags raw value storing the required modifier mask
    var modifierFlags: UInt64

    init(keyCode: CGKeyCode, modifierFlags: CGEventFlags) {
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags.rawValue
    }

    var eventFlags: CGEventFlags {
        CGEventFlags(rawValue: modifierFlags)
    }

    /// Default: Control+D
    static let defaultHotKey = KeyCombo(keyCode: 2, modifierFlags: .maskControl)
}

// MARK: - UserPreferences

final class UserPreferences {
    static let shared = UserPreferences()

    private let defaults = UserDefaults.standard

    // MARK: Hot key

    var hotKey: KeyCombo {
        get {
            guard let data = defaults.data(forKey: "hotKey"),
                  let combo = try? JSONDecoder().decode(KeyCombo.self, from: data) else {
                return .defaultHotKey
            }
            return combo
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "hotKey")
            }
        }
    }

    // MARK: TTS

    var ttsVoiceIdentifier: String {
        get { defaults.string(forKey: "ttsVoice") ?? "" }
        set { defaults.set(newValue, forKey: "ttsVoice") }
    }

    var ttsRate: Float {
        get {
            let stored = defaults.float(forKey: "ttsRate")
            return stored == 0 ? AVSpeechUtteranceDefaultSpeechRate : stored
        }
        set { defaults.set(newValue, forKey: "ttsRate") }
    }

    // MARK: App denylist

    var deniedApps: [String] {
        get { defaults.stringArray(forKey: "deniedApps") ?? [] }
        set { defaults.set(newValue, forKey: "deniedApps") }
    }

    // MARK: Voice command sensitivity  (0.0 – 1.0)

    var commandSensitivity: Double {
        get {
            let stored = defaults.double(forKey: "commandSensitivity")
            return stored == 0 ? 0.8 : stored
        }
        set { defaults.set(newValue, forKey: "commandSensitivity") }
    }

    private init() {}
}
