import CoreGraphics
import Foundation

/// Turns text into synthesized keyboard events for the focused application.
///
/// Each character is resolved through the active ``KeyboardLayout`` and posted
/// as a key-down / key-up pair via Quartz event services, so the target sees
/// genuine hardware-like keystrokes (works where clipboard paste is blocked).
///
/// Characters with no layout mapping are either typed directly as Unicode
/// (see ``unicodeFallback``) or reported back to the caller via the
/// `type(_:using:)` return value.
public final class KeystrokeEngine: @unchecked Sendable {

    /// Pause between characters. Some KVM/console targets drop events that
    /// arrive too fast; a small delay keeps input reliable.
    public var characterDelay: TimeInterval

    /// Maximum random variation, in seconds, added to each inter-character
    /// pause to make typing look less mechanical.
    ///
    /// When greater than zero, the effective delay per character is
    /// `max(0, characterDelay + Double.random(in: -jitter...jitter))`.
    /// Values `<= 0` disable jitter and use ``characterDelay`` verbatim.
    public var jitter: TimeInterval

    /// When `true`, characters with no ``KeyboardLayout`` mapping are typed
    /// directly via their Unicode scalar values instead of being skipped.
    /// When `false`, unmapped characters are reported back to the caller.
    public var unicodeFallback: Bool = true

    public init(characterDelay: TimeInterval = 0.012, jitter: TimeInterval = 0) {
        self.characterDelay = characterDelay
        self.jitter = jitter
    }

    /// Types `text` using `layout`. Returns the characters that could not be
    /// typed, so the caller can warn the user.
    ///
    /// A character ends up in the returned array only when it has no layout
    /// mapping *and* either ``unicodeFallback`` is `false` or the character
    /// could not be encoded as Unicode.
    @discardableResult
    public func type(_ text: String, using layout: KeyboardLayout) -> [Character] {
        var skipped: [Character] = []
        let source = CGEventSource(stateID: .combinedSessionState)

        for character in text {
            if let strokes = layout.strokes(for: character) {
                for stroke in strokes {
                    post(stroke, source: source)
                }
            } else if unicodeFallback {
                if !postUnicode(character, source: source) {
                    skipped.append(character)
                    continue
                }
            } else {
                skipped.append(character)
                continue
            }
            sleepAfterCharacter()
        }
        return skipped
    }

    /// Sleeps for the effective inter-character delay, applying ``jitter`` when set.
    private func sleepAfterCharacter() {
        var delay = characterDelay
        if jitter > 0 {
            delay = max(0, characterDelay + Double.random(in: -jitter...jitter))
        }
        if delay > 0 {
            Thread.sleep(forTimeInterval: delay)
        }
    }

    private func post(_ stroke: KeyStroke, source: CGEventSource?) {
        let down = CGEvent(keyboardEventSource: source, virtualKey: stroke.keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: stroke.keyCode, keyDown: false)
        down?.flags = stroke.flags
        up?.flags = stroke.flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    /// Posts `character` directly via its UTF-16 code units using a virtual-key-0
    /// key-down / key-up pair. Returns `false` if the events could not be created.
    private func postUnicode(_ character: Character, source: CGEventSource?) -> Bool {
        let utf16 = Array(String(character).utf16)
        guard !utf16.isEmpty,
              let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        else {
            return false
        }
        down.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
        up.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }
}
