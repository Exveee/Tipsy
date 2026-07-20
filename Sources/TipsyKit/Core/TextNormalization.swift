import Foundation

/// Per-rule switches for ``TextNormalization/normalize(_:options:)``.
///
/// Defaults are chosen per ``TargetProfile``: remote consoles want everything
/// normalized (typographic characters cannot be typed there at all), local
/// targets stay conservative.
public struct NormalizationOptions: Equatable, Sendable {
    public init() {}
}

/// Rewrites clipboard text so that typographic characters pasted from
/// Word/Slack/browsers (smart quotes, NBSP, soft hyphens, CRLF, …) become
/// their typeable ASCII equivalents before the layout lookup runs.
public enum TextNormalization {
    /// Returns `text` with the rules enabled in `options` applied.
    /// Idempotent: `normalize(normalize(x)) == normalize(x)`.
    public static func normalize(_ text: String, options: NormalizationOptions) -> String {
        // Stub — filled in by the text track (issue #27).
        _ = options
        return text
    }
}
