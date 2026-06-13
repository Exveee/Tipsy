import AppKit

/// Shared formatting for the trigger hotkey: a human-readable combo string
/// (for Preferences) and a menu key-equivalent (so the menu bar item shows the
/// *configured* shortcut instead of a hardcoded one).
enum HotkeyFormat {

    /// Modifier flags Tipsy cares about, in display order ⌃⌥⇧⌘.
    static let relevantModifiers: NSEvent.ModifierFlags = [.control, .option, .shift, .command]

    /// Formats a `(keyCode, modifiers)` pair into a combo such as `⌘⇧T`.
    static func display(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        result += keyName(for: keyCode)
        return result
    }

    /// The character a key code produces for use as an `NSMenuItem.keyEquivalent`,
    /// or `nil` for keys without a plain character (arrows, F-keys, …) — in which
    /// case the menu item should carry no accelerator rather than a wrong one.
    static func menuKeyEquivalent(for keyCode: UInt16) -> String? {
        keyChar[keyCode]
    }

    /// Display names for common virtual key codes, with a `keyN` fallback.
    static func keyName(for keyCode: UInt16) -> String {
        switch keyCode {
        case 48: return "⇥"        // Tab
        case 49: return "Space"
        case 36: return "↩"        // Return
        case 51: return "⌫"        // Delete
        case 53: return "⎋"        // Escape
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        default:
            if let ch = keyChar[keyCode] { return ch.uppercased() }
            return "key\(keyCode)"
        }
    }

    /// Virtual key code → the plain (lowercase) character it types on ANSI.
    private static let keyChar: [UInt16: String] = [
        0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x",
        8: "c", 9: "v", 11: "b", 12: "q", 13: "w", 14: "e", 15: "r", 16: "y",
        17: "t", 31: "o", 32: "u", 34: "i", 35: "p", 37: "l", 38: "j", 40: "k",
        45: "n", 46: "m",
        18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8",
        25: "9", 29: "0",
        24: "=", 27: "-", 30: "]", 33: "[", 39: "'", 41: ";", 42: "\\",
        43: ",", 44: "/", 47: ".", 50: "`"
    ]
}
