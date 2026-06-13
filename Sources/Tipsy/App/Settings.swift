import AppKit
import Foundation
import TipsyKit

/// Persisted user settings backed by `UserDefaults.standard`.
///
/// Each property reads/writes a single defaults key on access, so values are
/// always in sync with disk and survive relaunches. Defaults are returned when
/// a key has never been written.
@MainActor
enum Settings {

    private static let defaults = UserDefaults.standard

    private enum Key {
        static let layoutID = "tipsy.layoutID"
        static let characterDelay = "tipsy.characterDelay"
        static let jitter = "tipsy.jitter"
        static let unicodeFallback = "tipsy.unicodeFallback"
        static let leadTime = "tipsy.leadTime"
        static let hotkeyEnabled = "tipsy.hotkeyEnabled"
        static let hotkeyKeyCode = "tipsy.hotkeyKeyCode"
        static let hotkeyModifiers = "tipsy.hotkeyModifiers"
        static let cueSoundEnabled = "tipsy.cueSoundEnabled"
        static let cueVolume = "tipsy.cueVolume"
        static let cueVariant = "tipsy.cueVariant"
    }

    /// Default trigger combo: ⌘⇧V (virtual key code 9).
    private static let defaultKeyCode = 9
    private static let defaultModifiers = ([.command, .shift] as NSEvent.ModifierFlags).rawValue

    /// Clamps `value` into the closed range `[lo, hi]`.
    private static func clamp<T: Comparable>(_ value: T, _ lo: T, _ hi: T) -> T {
        min(max(value, lo), hi)
    }

    /// Identifier of the default keyboard layout. Defaults to the first layout.
    static var layoutID: String {
        get { defaults.string(forKey: Key.layoutID) ?? Layouts.all[0].id }
        set { defaults.set(newValue, forKey: Key.layoutID) }
    }

    /// Inter-character delay in seconds. Defaults to `0.012`. Persisted values are
    /// clamped to the UI range `0...0.2`.
    static var characterDelay: Double {
        get { clamp(defaults.object(forKey: Key.characterDelay) as? Double ?? 0.012, 0, 0.2) }
        set { defaults.set(newValue, forKey: Key.characterDelay) }
    }

    /// Random per-character timing variation in seconds. Defaults to `0`. Persisted
    /// values are clamped to the UI range `0...0.1`.
    static var jitter: Double {
        get { clamp(defaults.object(forKey: Key.jitter) as? Double ?? 0, 0, 0.1) }
        set { defaults.set(newValue, forKey: Key.jitter) }
    }

    /// Whether unmapped characters are typed via Unicode. Defaults to `true`.
    static var unicodeFallback: Bool {
        get { defaults.object(forKey: Key.unicodeFallback) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.unicodeFallback) }
    }

    /// Countdown before typing starts, in seconds. Defaults to `3`. Persisted values
    /// are clamped to the UI range `0...10`.
    static var leadTime: Double {
        get { clamp(defaults.object(forKey: Key.leadTime) as? Double ?? 3, 0, 10) }
        set { defaults.set(newValue, forKey: Key.leadTime) }
    }

    /// Whether the global hotkey is active. Defaults to `true`.
    static var hotkeyEnabled: Bool {
        get { defaults.object(forKey: Key.hotkeyEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.hotkeyEnabled) }
    }

    /// Virtual key code of the trigger hotkey. Defaults to `9` (the 'V' key).
    ///
    /// A stored value outside the valid virtual-key-code range `0...65535` is
    /// treated as corrupt and falls back to ``defaultKeyCode``, so callers can
    /// safely convert the result with `UInt16(...)` without trapping.
    static var hotkeyKeyCode: Int {
        get {
            let stored = defaults.object(forKey: Key.hotkeyKeyCode) as? Int ?? defaultKeyCode
            return (0...65535).contains(stored) ? stored : defaultKeyCode
        }
        set { defaults.set(newValue, forKey: Key.hotkeyKeyCode) }
    }

    /// Modifier flags of the trigger hotkey, stored as
    /// `NSEvent.ModifierFlags.rawValue`. Defaults to `[.command, .shift]`.
    static var hotkeyModifiers: UInt {
        get { (defaults.object(forKey: Key.hotkeyModifiers) as? UInt) ?? defaultModifiers }
        set { defaults.set(newValue, forKey: Key.hotkeyModifiers) }
    }

    /// Whether the distinctive cue sound plays before typing. Defaults to `true`.
    static var cueSoundEnabled: Bool {
        get { defaults.object(forKey: Key.cueSoundEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.cueSoundEnabled) }
    }

    /// Cue volume, 0–1. Defaults to `0.7`. Persisted values are clamped to `0...1`.
    static var cueVolume: Double {
        get { clamp(defaults.object(forKey: Key.cueVolume) as? Double ?? 0.7, 0, 1) }
        set { defaults.set(newValue, forKey: Key.cueVolume) }
    }

    /// Selected cue motif (a ``CueVariant`` raw value). Defaults to `"rising"`.
    static var cueVariant: String {
        get { defaults.string(forKey: Key.cueVariant) ?? CueVariant.rising.rawValue }
        set { defaults.set(newValue, forKey: Key.cueVariant) }
    }
}
