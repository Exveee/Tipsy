import CoreGraphics
import Foundation

/// Turns text into synthesized keyboard events for the focused application.
///
/// Each character is resolved through the active ``KeyboardLayout`` and posted
/// as a key-down / key-up pair via Quartz event services, so the target sees
/// genuine hardware-like keystrokes (works where clipboard paste is blocked).
final class KeystrokeEngine: @unchecked Sendable {

    /// Pause between characters. Some KVM/console targets drop events that
    /// arrive too fast; a small delay keeps input reliable.
    var characterDelay: TimeInterval

    init(characterDelay: TimeInterval = 0.012) {
        self.characterDelay = characterDelay
    }

    /// Types `text` using `layout`. Returns characters that had no mapping
    /// and were skipped, so the caller can warn the user.
    @discardableResult
    func type(_ text: String, using layout: KeyboardLayout) -> [Character] {
        var skipped: [Character] = []
        let source = CGEventSource(stateID: .combinedSessionState)

        for character in text {
            guard let stroke = layout.keyStroke(for: character) else {
                skipped.append(character)
                continue
            }
            post(stroke, source: source)
            if characterDelay > 0 {
                Thread.sleep(forTimeInterval: characterDelay)
            }
        }
        return skipped
    }

    private func post(_ stroke: KeyStroke, source: CGEventSource?) {
        let down = CGEvent(keyboardEventSource: source, virtualKey: stroke.keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: stroke.keyCode, keyDown: false)
        down?.flags = stroke.flags
        up?.flags = stroke.flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
