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
    /// All available layouts, in menu order. ``DynamicLocalLayout`` leads as the
    /// first `.appleLocal` choice — the default when the `.localMac` profile
    /// needs a layout — while ``defaultLayoutID`` keeps a fresh install on German
    /// so upgrading users see no change.
    public static let all: [KeyboardLayout] = [DynamicLocalLayout(), GermanLayout(), USLayout(), UKLayout(), SwissGermanLayout(), GermanPCLayout(), USPCLayout()]

    /// Identifier of the layout a fresh install starts on. Kept as German
    /// (not `all[0]`) so upgrading users — and anyone who never touched the
    /// picker — keep the pre-target-mode default.
    public static let defaultLayoutID = "de"

    /// The registered layouts whose ``KeyboardLayout/kind`` matches `kind`, in
    /// registry order. Pure: drives both the menu and Preferences filtering.
    public static func matching(kind: LayoutKind) -> [KeyboardLayout] {
        all.filter { $0.kind == kind }
    }

    /// Resolves which layout id to use for `profile`, given the `current`
    /// selection: keeps `current` when its kind already matches the profile,
    /// otherwise returns the first matching layout's id (or `current` unchanged
    /// if — impossibly — none match). Pure; the app persists the result.
    public static func resolvedLayoutID(for profile: TargetProfile, current: String) -> String {
        let kind = profile.layoutKind
        if let layout = all.first(where: { $0.id == current }), layout.kind == kind {
            return current
        }
        return matching(kind: kind).first?.id ?? current
    }
}
