import Carbon.HIToolbox
import CoreGraphics
import Foundation
import os

/// A ``KeyboardLayout`` that reverse-maps characters through the **actual
/// current macOS input source** instead of a static per-country table.
///
/// Where ``GermanLayout`` and friends hard-code which key position produces
/// each character, this layout asks the live input source — via
/// `TISCopyCurrentKeyboardInputSource` + `UCKeyTranslate` — so it follows
/// whatever the user has selected (German, Dvorak, a custom bundle, …) without
/// shipping a table for it. It is the natural fit for the `.localMac` target,
/// where macOS composes the posted key codes through that same source.
///
/// The character → stroke map is built lazily on first lookup and cached. It is
/// invalidated when the selected input source changes
/// (`kTISNotifySelectedKeyboardInputSourceChanged`) so the next lookup rebuilds
/// against the new source. All cached state is guarded by an
/// `OSAllocatedUnfairLock` because the engine calls into the layout from a
/// background typing queue while the main actor owns the instance.
///
/// Input sources without Unicode layout data (CJK and other input methods
/// expose no `kTISPropertyUnicodeKeyLayoutData`) yield an empty map: every
/// character is reported unmapped and the engine's own fallback takes over.
public final class DynamicLocalLayout: KeyboardLayout {

    public let id = "dynamic"
    public let kind: LayoutKind = .appleLocal

    /// Cached reverse map, guarded by the lock. Every field is `Sendable`, so
    /// the plain `withLock` API applies.
    private struct Cache {
        var built = false
        /// Single-stroke characters: minimal modifier combo wins.
        var single: [Character: KeyStroke] = [:]
        /// Dead-key characters served as `[accent, space]` two-stroke sequences.
        var multi: [Character: [KeyStroke]] = [:]
    }

    private let lock = OSAllocatedUnfairLock(initialState: Cache())

    /// Distributed-notification observer token. Held in its own unchecked lock
    /// because `NSObjectProtocol` is not `Sendable`; it never leaves this class.
    private let observerToken = OSAllocatedUnfairLock<(any NSObjectProtocol)?>(uncheckedState: nil)

    public init() {
        // All stored properties have inline defaults, so `self` is fully
        // initialized here and may be captured by the notification block.
        let token = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.invalidate()
        }
        observerToken.withLockUnchecked { $0 = token }
    }

    deinit {
        if let token = observerToken.withLockUnchecked({ $0 }) {
            DistributedNotificationCenter.default().removeObserver(token)
        }
    }

    /// Live localized name of the current input source, e.g. `"German"`.
    /// Read on demand (cheap) so it tracks source switches without a rebuild.
    public var displayName: String {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let namePtr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) else {
            return "Dynamic (Local)"
        }
        let name = Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String
        return "\(name) (Local)"
    }

    public func keyStroke(for character: Character) -> KeyStroke? {
        ensureBuilt()
        return lock.withLock { $0.single[character] }
    }

    public func strokes(for character: Character) -> [KeyStroke]? {
        ensureBuilt()
        return lock.withLock { cache in
            // Prefer the single-stroke mapping when a character is reachable
            // both directly and as a dead-key literal.
            if let stroke = cache.single[character] {
                return [stroke]
            }
            return cache.multi[character]
        }
    }

    /// Drops the cache so the next lookup rebuilds against the current source.
    /// The observer token is preserved.
    private func invalidate() {
        lock.withLock { cache in
            cache.built = false
            cache.single = [:]
            cache.multi = [:]
        }
    }

    /// Builds the map on first use. Holding the lock during the build serializes
    /// concurrent first lookups; the build is a few hundred `UCKeyTranslate`
    /// calls, so it stays cheap.
    private func ensureBuilt() {
        lock.withLock { cache in
            guard !cache.built else { return }
            let (single, multi) = Self.buildMap()
            cache.single = single
            cache.multi = multi
            cache.built = true
        }
    }

    // MARK: - Reverse mapping via UCKeyTranslate

    /// The four modifier combinations we probe, ordered simplest first so the
    /// cheapest combo wins the character when it is reachable several ways.
    ///
    /// `UCKeyTranslate` wants the Carbon modifier byte, i.e. the high byte of the
    /// classic `EventModifiers` mask (`shiftKey`/`optionKey` shifted right 8).
    private static let combos: [(state: UInt32, shift: Bool, option: Bool)] = [
        (0, false, false),
        (UInt32(shiftKey >> 8), true, false),
        (UInt32(optionKey >> 8), false, true),
        (UInt32((shiftKey | optionKey) >> 8), true, true)
    ]

    /// Enumerates key codes 0...127 across the four modifier combos on the
    /// current input source and returns the `single`/`multi` reverse maps.
    ///
    /// Returns empty maps when the source has no Unicode layout data (input
    /// methods): callers then fall through to the engine's own handling.
    private static func buildMap() -> (single: [Character: KeyStroke], multi: [Character: [KeyStroke]]) {
        var single: [Character: KeyStroke] = [:]
        var multi: [Character: [KeyStroke]] = [:]

        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let layoutPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return (single, multi)
        }
        let layoutData = Unmanaged<CFData>.fromOpaque(layoutPtr).takeUnretainedValue()
        let keyboardType = UInt32(LMGetKbdType())

        withExtendedLifetime(layoutData) {
            guard let bytes = CFDataGetBytePtr(layoutData) else { return }
            let keyLayout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)

            // Combo-outer so that every character reachable with fewer modifiers
            // is recorded before a costlier combo can claim it.
            for combo in combos {
                for keyCode in UInt16(0)...UInt16(127) {
                    var deadKeyState: UInt32 = 0
                    let produced = translate(keyLayout, keyCode, combo.state, keyboardType, &deadKeyState)

                    if deadKeyState != 0 {
                        // Dead key: press SPACE to resolve the literal accent.
                        var followState = deadKeyState
                        let accent = translate(keyLayout, UInt16(VK.space), 0, keyboardType, &followState)
                        guard accent.count == 1, let ch = accent.first else { continue }
                        if single[ch] == nil && multi[ch] == nil {
                            multi[ch] = [
                                KeyStroke(keyCode: CGKeyCode(keyCode), shift: combo.shift, option: combo.option),
                                KeyStroke(keyCode: VK.space)
                            ]
                        }
                    } else if produced.count == 1, let ch = produced.first {
                        if single[ch] == nil {
                            single[ch] = KeyStroke(keyCode: CGKeyCode(keyCode), shift: combo.shift, option: combo.option)
                        }
                    }
                }
            }
        }

        // Guarantee the universal whitespace characters regardless of what
        // UCKeyTranslate reports (RETURN yields U+000D, not "\n"; TAB and the
        // control keys are inconsistent across sources).
        single[" "] = KeyStroke(keyCode: VK.space)
        single["\t"] = KeyStroke(keyCode: VK.tab)
        single["\n"] = KeyStroke(keyCode: VK.return)

        return (single, multi)
    }

    /// One `UCKeyTranslate` call in the *key-down* action, returning the produced
    /// string (empty on failure). `deadKeyState` is threaded in/out so callers
    /// can both detect a dead key (non-zero out) and resolve it (feed it back
    /// with a following SPACE).
    private static func translate(_ keyLayout: UnsafePointer<UCKeyboardLayout>,
                                  _ keyCode: UInt16,
                                  _ modifierKeyState: UInt32,
                                  _ keyboardType: UInt32,
                                  _ deadKeyState: inout UInt32) -> String {
        var chars = [UniChar](repeating: 0, count: 8)
        var length = 0
        let status = UCKeyTranslate(
            keyLayout,
            keyCode,
            UInt16(kUCKeyActionDown),
            modifierKeyState,
            keyboardType,
            OptionBits(0),
            &deadKeyState,
            chars.count,
            &length,
            &chars
        )
        guard status == noErr, length > 0 else { return "" }
        return String(utf16CodeUnits: chars, count: length)
    }
}
