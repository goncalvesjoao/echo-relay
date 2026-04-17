import CoreGraphics
import Foundation

// MARK: - HotKeyManager

/// Installs a CGEventTap to intercept the global hotkey and fire `onToggle`.
final class HotKeyManager {

    // A module-level pointer so the C callback can reach the active manager
    // without unsafe bridging inside the closure.
    fileprivate static weak var current: HotKeyManager?

    // MARK: Public interface

    var hotKey: KeyCombo = UserPreferences.shared.hotKey
    var onToggle: (() -> Void)?

    // MARK: Private state

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // MARK: Lifecycle

    func start() {
        guard eventTap == nil else { return }

        HotKeyManager.current = self

        let eventMask: CGEventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: hotKeyEventTapCallback,
            userInfo: nil
        ) else {
            print("[HotKeyManager] Failed to create event tap – grant Accessibility access.")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        HotKeyManager.current = nil
    }
}

// MARK: - C-compatible event tap callback

/// Free function with the required `@convention(c)` signature required by CGEvent.tapCreate.
private func hotKeyEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {

    guard type == .keyDown, let manager = HotKeyManager.current else {
        return Unmanaged.passRetained(event)
    }

    let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
    let relevantFlags: CGEventFlags = [.maskControl, .maskShift, .maskAlternate, .maskCommand, .maskSecondaryFn]
    let presentFlags = event.flags.intersection(relevantFlags)
    let expectedFlags = manager.hotKey.eventFlags.intersection(relevantFlags)

    if keyCode == manager.hotKey.keyCode && presentFlags == expectedFlags {
        DispatchQueue.main.async { manager.onToggle?() }
        return nil  // suppress – don't pass the keystroke to other apps
    }

    return Unmanaged.passRetained(event)
}
