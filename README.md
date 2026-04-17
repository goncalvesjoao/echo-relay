# EchoRelay

Hands-free voice bridge for AI agents — speak, type, and listen without touching the keyboard.

## What it does

EchoRelay is a macOS menu-bar app that:

1. **Listens** — press **Control+D** to start dictating. SFSpeechRecognizer transcribes your voice in real-time and types it into whatever app is focused.
2. **Reads aloud** — monitors the frontmost app's accessibility tree; when new text appears in a content area (chat pane, terminal output, …) it reads it back via AVSpeechSynthesizer.
3. **Responds to voice commands** — while speaking or dictating you can say *"pause"*, *"resume"*, *"skip"*, *"reread"*, *"stop"*, or *"done"* to control playback/input.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    EchoRelay                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │ SpeechInput │  │ AppMonitor  │  │ TTSEngine   │  │
│  │ - SFSpeech  │  │ - AXUIElement│ │ - AVSpeech  │  │
│  │ - CGEvent   │  │ - Heuristics │  │ - Controls  │  │
│  │ - HUD       │  │             │  │             │  │
│  └─────────────┘  └─────────────┘  └─────────────┘  │
│         │               │                │          │
│         └───────────────┴────────────────┘          │
│                    VoiceCommandRouter                │
│         (parses "stop", "pause", etc.)              │
└─────────────────────────────────────────────────────┘
```

| Component | File | Responsibility |
|---|---|---|
| `HotKeyManager` | `HotKey/HotKeyManager.swift` | CGEventTap intercepts Control+D globally |
| `SpeechInputManager` | `Speech/SpeechInputManager.swift` | SFSpeechRecognizer + AVAudioEngine lifecycle |
| `KeyboardSimulator` | `Speech/KeyboardSimulator.swift` | CGEvent Unicode keystroke injection |
| `VoiceCommandRouter` | `Speech/VoiceCommandRouter.swift` | Dispatches commands vs. plain text |
| `AppMonitor` | `Monitor/AppMonitor.swift` | AXUIElement polling + content diffing |
| `TTSEngine` | `TTS/TTSEngine.swift` | AVSpeechSynthesizer queue + pause/resume/skip/reread |
| `HUDWindow` | `HUD/HUDWindow.swift` | Borderless, draggable, always-on-top NSPanel |
| `MenuBarController` | `MenuBar/MenuBarController.swift` | NSStatusItem + dropdown menu |
| `SettingsWindowController` | `Settings/SettingsWindowController.swift` | Hotkey, TTS voice/rate, denylist |
| `UserPreferences` | `Settings/UserPreferences.swift` | Persisted settings via UserDefaults |

## Requirements

- macOS 12.0+
- Xcode 15+ / Swift 5.9+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (to generate the `.xcodeproj`)

## Build

```bash
# Install XcodeGen if you don't have it
brew install xcodegen

# Generate the Xcode project
cd EchoRelay
xcodegen generate

# Open and build
open EchoRelay.xcodeproj
```

Or build from the command line:

```bash
cd EchoRelay
xcodegen generate
xcodebuild -project EchoRelay.xcodeproj \
           -scheme EchoRelay \
           -configuration Debug \
           build
```

## Permissions

EchoRelay requires three macOS privacy permissions (prompted on first use):

| Permission | Purpose |
|---|---|
| **Microphone** | Capture audio for speech recognition |
| **Speech Recognition** | Transcribe spoken audio to text |
| **Accessibility** | Read app content for TTS; install global event tap |

## Voice commands

| Say | Effect |
|---|---|
| *"pause"* | Pause TTS |
| *"resume"* | Resume paused TTS |
| *"skip"* | Skip current utterance |
| *"reread"* | Repeat the last 3 sentences |
| *"stop"* | Stop TTS entirely |
| *"done"* | Stop listening (end dictation) |

## Settings

Open **Settings…** from the menu bar icon or press **⌘,** while the settings window has focus.

- **Global Hotkey** — change the toggle shortcut (default: Control+D)
- **TTS Voice** — pick from all English system voices
- **Speech Rate** — adjust how fast text is read back
- **Skip Apps** — comma-separated bundle IDs of apps that should not be monitored
