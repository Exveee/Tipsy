import Carbon.HIToolbox
import Foundation

/// Detects when the user's selected keyboard layout no longer matches the
/// macOS input source that will actually interpret the posted key codes.
///
/// Apple-local layouts (``GermanLayout`` etc.) choose key *positions* on the
/// assumption a specific input source is active — German positions only compose
/// German characters while `com.apple.keylayout.German` is selected. If the user
/// switches macOS to, say, US while Tipsy is still set to German, the typed text
/// comes out wrong. This type supplies the pure matching logic; surfacing the
/// warning and remembering the user's choice belong to the app layer.
public enum InputSourceMatch {

    /// Input-source ID prefixes each Tipsy layout expects to be active.
    ///
    /// This is a deliberately self-contained table: the layout files are owned
    /// by other tracks, so the expectation lives here instead of on the layouts.
    /// An empty list means "matches anything" — used by the dynamic layout,
    /// which reads whatever source is active, and returned for unknown IDs.
    public static func expectedPrefixes(for layoutID: String) -> [String] {
        switch layoutID {
        case "de", "de-pc": return ["com.apple.keylayout.German"]
        case "us", "us-pc": return ["com.apple.keylayout.US", "com.apple.keylayout.ABC"]
        case "uk": return ["com.apple.keylayout.British"]
        case "ch-de": return ["com.apple.keylayout.SwissGerman"]
        case "dynamic": return []
        default: return []
        }
    }

    /// Whether `inputSourceID` satisfies the expectation for `layoutID`.
    ///
    /// A layout matches when the active source ID begins with any of its
    /// expected prefixes. An empty expectation list (dynamic or unknown layout)
    /// always matches.
    public static func matches(inputSourceID: String, layoutID: String) -> Bool {
        let prefixes = expectedPrefixes(for: layoutID)
        guard !prefixes.isEmpty else { return true }
        return prefixes.contains { inputSourceID.hasPrefix($0) }
    }

    /// The identifier of the currently selected keyboard input source, e.g.
    /// `"com.apple.keylayout.German"`, or `nil` if it cannot be read.
    public static func currentInputSourceID() -> String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else {
            return nil
        }
        return Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
    }
}
