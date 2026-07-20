/// Maps Unicode characters to the physical key strokes that produce them
/// on a given national keyboard layout.
///
/// Implementations are pure lookup tables so they are trivially testable
/// without touching the event system.
/// The interpretation domain a layout's key positions are written for.
public enum LayoutKind: Sendable, Equatable {
    /// Positions chosen so the **local macOS input source** composes the right
    /// character (Apple layouts, left Option for ⌥ symbols).
    case appleLocal
    /// Positions chosen so a **remote host behind a scancode-forwarding KVM**
    /// composes the right character with its PC layout (AltGr = right Option).
    case pcScancode
}

public protocol KeyboardLayout: Sendable {
    /// Stable identifier used in settings, e.g. `"de"`.
    var id: String { get }
    /// Human-readable name shown in the menu, e.g. `"German (QWERTZ)"`.
    var displayName: String { get }
    /// Which interpretation domain the positions target. Defaults to
    /// `.appleLocal`.
    var kind: LayoutKind { get }
    /// The key stroke that types `character`, or `nil` if unsupported.
    func keyStroke(for character: Character) -> KeyStroke?
    /// Ordered key strokes that produce `character`; `nil` if unmapped.
    ///
    /// Multi-stroke layouts (dead keys) override this; single-stroke layouts
    /// rely on the default implementation below.
    func strokes(for character: Character) -> [KeyStroke]?
}

public extension KeyboardLayout {
    /// Ordered key strokes that produce `character`; nil if unmapped.
    /// Default: the single mapping from keyStroke(for:), wrapped in an array.
    func strokes(for character: Character) -> [KeyStroke]? {
        keyStroke(for: character).map { [$0] }
    }

    /// Existing layouts are Apple-local unless they say otherwise.
    var kind: LayoutKind { .appleLocal }
}

/// Registry of layouts shipped with Tipsy.
public enum Layouts {
    /// All available layouts. The first entry is the default.
    public static let all: [KeyboardLayout] = [GermanLayout(), USLayout(), UKLayout(), SwissGermanLayout()]
}
