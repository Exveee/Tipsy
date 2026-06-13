import Foundation

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
    }

    /// Identifier of the default keyboard layout. Defaults to the first layout.
    static var layoutID: String {
        get { defaults.string(forKey: Key.layoutID) ?? Layouts.all[0].id }
        set { defaults.set(newValue, forKey: Key.layoutID) }
    }

    /// Inter-character delay in seconds. Defaults to `0.012`.
    static var characterDelay: Double {
        get { defaults.object(forKey: Key.characterDelay) as? Double ?? 0.012 }
        set { defaults.set(newValue, forKey: Key.characterDelay) }
    }

    /// Random per-character timing variation in seconds. Defaults to `0`.
    static var jitter: Double {
        get { defaults.object(forKey: Key.jitter) as? Double ?? 0 }
        set { defaults.set(newValue, forKey: Key.jitter) }
    }

    /// Whether unmapped characters are typed via Unicode. Defaults to `true`.
    static var unicodeFallback: Bool {
        get { defaults.object(forKey: Key.unicodeFallback) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.unicodeFallback) }
    }

    /// Countdown before typing starts, in seconds. Defaults to `3`.
    static var leadTime: Double {
        get { defaults.object(forKey: Key.leadTime) as? Double ?? 3 }
        set { defaults.set(newValue, forKey: Key.leadTime) }
    }

    /// Whether the global hotkey is active. Defaults to `true`.
    static var hotkeyEnabled: Bool {
        get { defaults.object(forKey: Key.hotkeyEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.hotkeyEnabled) }
    }
}
