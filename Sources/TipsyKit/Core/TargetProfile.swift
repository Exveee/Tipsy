import Foundation

/// Where the synthesized keystrokes are ultimately interpreted.
///
/// The profile is the user-facing concept that replaces "which keyboard do I
/// have" with "where am I typing to". It drives which layouts are offered
/// (`LayoutKind`), whether the Unicode fallback is allowed, and how hard the
/// engine paces events.
public enum TargetProfile: String, CaseIterable, Sendable {

    /// Typing into an app running on this Mac. macOS composes the posted key
    /// codes through the active input source, and the Unicode fallback works
    /// because local apps read the event's attached string.
    case localMac

    /// Typing into a remote machine through a KVM / VNC / IPMI / web console.
    /// Those clients forward key *positions* and real modifier state; the
    /// remote OS interprets them with its own (PC) layout. The Unicode
    /// fallback is unusable here: clients see only the virtual key code, and
    /// key code 0 is the `A` key — every fallback character would arrive as a
    /// stray `a`.
    case remoteConsole

    /// Whether the engine may type unmapped characters via
    /// `keyboardSetUnicodeString`. Only safe for local targets.
    public var allowsUnicodeFallback: Bool {
        switch self {
        case .localMac: return true
        case .remoteConsole: return false
        }
    }

    /// Default pause between the individual events of one stroke (modifier
    /// down → key down → key up → modifier up). Remote web consoles batch
    /// events over a websocket and can process a key press before the
    /// preceding Shift/Option press has registered; a small gap prevents that.
    public var defaultInterEventDelay: TimeInterval {
        switch self {
        case .localMac: return 0
        case .remoteConsole: return 0.008
        }
    }

    /// The layout family this profile types with.
    public var layoutKind: LayoutKind {
        switch self {
        case .localMac: return .appleLocal
        case .remoteConsole: return .pcScancode
        }
    }
}
