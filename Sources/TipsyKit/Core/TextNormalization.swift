import Foundation

/// Per-rule switches for ``TextNormalization/normalize(_:options:)``.
///
/// Defaults are chosen per ``TargetProfile``: remote consoles want everything
/// normalized (typographic characters cannot be typed there at all), local
/// targets stay conservative — see ``remoteConsole`` and ``localMac``.
public struct NormalizationOptions: Equatable, Sendable {

    /// Rewrites curly/guillemet quotes to ASCII.
    /// „ “ ” ‟ » « ‹ › → `"` ; ‘ ’ ‚ ‛ ′ → `'`
    public var smartQuotes: Bool

    /// Rewrites en dash, em dash, figure dash, and horizontal bar to the ASCII
    /// hyphen `-`. The ASCII hyphen itself is never touched.
    public var dashes: Bool

    /// Rewrites non-breaking, narrow non-breaking, thin, en, em, and
    /// ideographic spaces to a regular ASCII space.
    public var spaces: Bool

    /// Removes characters with no visible glyph: soft hyphen, zero-width
    /// space/joiner/non-joiner, byte-order mark, and word joiner.
    public var invisibles: Bool

    /// Rewrites CRLF and lone CR line endings to LF.
    public var lineEndings: Bool

    /// Rewrites the horizontal ellipsis `…` to three ASCII periods `...`.
    public var ellipsis: Bool

    public init(smartQuotes: Bool = true,
                dashes: Bool = true,
                spaces: Bool = true,
                invisibles: Bool = true,
                lineEndings: Bool = true,
                ellipsis: Bool = true) {
        self.smartQuotes = smartQuotes
        self.dashes = dashes
        self.spaces = spaces
        self.invisibles = invisibles
        self.lineEndings = lineEndings
        self.ellipsis = ellipsis
    }

    /// Every rule enabled. Remote consoles have no Unicode fallback (see
    /// ``TargetProfile/allowsUnicodeFallback``), so typographic characters
    /// must be rewritten to their ASCII equivalents before the layout lookup
    /// runs — otherwise they cannot be typed at all.
    public static let remoteConsole = NormalizationOptions()

    /// Only ``lineEndings`` and ``invisibles`` enabled; quotes, dashes,
    /// spaces, and the ellipsis pass through untouched. Local apps can type
    /// those characters directly via the Unicode fallback, so rewriting them
    /// here would needlessly change text the user pasted on purpose.
    public static let localMac = NormalizationOptions(smartQuotes: false,
                                                        dashes: false,
                                                        spaces: false,
                                                        invisibles: true,
                                                        lineEndings: true,
                                                        ellipsis: false)
}

/// Rewrites clipboard text so that typographic characters pasted from
/// Word/Slack/browsers (smart quotes, NBSP, soft hyphens, CRLF, …) become
/// their typeable ASCII equivalents before the layout lookup runs.
public enum TextNormalization {

    /// Returns `text` with the rules enabled in `options` applied.
    ///
    /// Pure and idempotent: `normalize(normalize(x), options: o) ==
    /// normalize(x, options: o)`. Runs in a single pass over `text`'s
    /// Unicode scalars — each one is independently mapped to its replacement
    /// (or left unchanged), so rule order never matters because no two rules
    /// claim the same scalar.
    ///
    /// Deliberately walks `unicodeScalars` rather than `Character`s (Swift's
    /// grapheme clusters): join-control scalars like the zero-width joiner
    /// attach to the *preceding* scalar to form a single `Character` (e.g.
    /// `"a\u{200D}"` is one grapheme cluster), which would put them out of
    /// reach of a per-`Character` removal pass.
    public static func normalize(_ text: String, options: NormalizationOptions) -> String {
        let scalars = Array(text.unicodeScalars)
        var result = String.UnicodeScalarView()
        result.reserveCapacity(scalars.count)

        var index = 0
        while index < scalars.count {
            let scalar = scalars[index]

            // CRLF is two scalars, not one, so it needs a one-scalar lookahead
            // rather than a table entry: fold both into a single LF and skip
            // the LF we just consumed.
            if options.lineEndings, scalar == "\r" {
                result.append("\n")
                if index + 1 < scalars.count, scalars[index + 1] == "\n" {
                    index += 1
                }
                index += 1
                continue
            }

            result.append(contentsOf: replacement(for: scalar, options: options).unicodeScalars)
            index += 1
        }
        return String(result)
    }

    /// Returns what a single `scalar` becomes under `options`: the empty
    /// string if it is removed, a multi-scalar string if it expands (e.g.
    /// `…` → `...`), or the scalar itself unchanged. Line endings are handled
    /// separately in ``normalize(_:options:)`` since CRLF spans two scalars.
    private static func replacement(for scalar: Unicode.Scalar, options: NormalizationOptions) -> String {
        if options.smartQuotes {
            switch scalar {
            case "\u{201E}", "\u{201C}", "\u{201D}", "\u{201F}", "\u{00BB}", "\u{00AB}", "\u{2039}", "\u{203A}":
                return "\""
            case "\u{2018}", "\u{2019}", "\u{201A}", "\u{201B}", "\u{2032}":
                return "'"
            default:
                break
            }
        }
        if options.dashes {
            switch scalar {
            case "\u{2013}", "\u{2014}", "\u{2012}", "\u{2015}":
                return "-"
            default:
                break
            }
        }
        if options.spaces {
            switch scalar {
            case "\u{00A0}", "\u{202F}", "\u{2009}", "\u{2002}", "\u{2003}", "\u{3000}":
                return " "
            default:
                break
            }
        }
        if options.invisibles {
            switch scalar {
            case "\u{00AD}", "\u{200B}", "\u{200D}", "\u{200C}", "\u{FEFF}", "\u{2060}":
                return ""
            default:
                break
            }
        }
        if options.ellipsis, scalar == "\u{2026}" {
            return "..."
        }
        return String(scalar)
    }
}
