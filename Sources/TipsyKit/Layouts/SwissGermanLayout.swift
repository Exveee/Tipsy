import CoreGraphics

/// Swiss German (QWERTZ), Apple layout.
///
/// Coverage is best-effort and NOT verified on real Swiss-German hardware.
/// Confident mappings: letters (Y/Z swap), the accent/umlaut keys shared with
/// the French-Swiss hardware (à ä, é ö, è ü), the digit row with Swiss shifted
/// symbols (incl. `ç`), comma/period punctuation and whitespace.
///
/// The Option-layer symbols (brackets, braces, pipe, backslash, `@`) are
/// borrowed from the Apple German positions and are marked TODO until they can
/// be verified on hardware. Swiss German has no `ß`. Anything left unmapped
/// falls back to the engine's Unicode typing.
public struct SwissGermanLayout: KeyboardLayout {
    public let id = "ch-de"
    public let displayName = "Swiss German (QWERTZ)"

    private let table: [Character: KeyStroke]

    public init() {
        var t: [Character: KeyStroke] = [:]

        // Letters keep US positions except Y and Z are swapped on QWERTZ.
        var letters = VK.ansiLetters
        letters["y"] = VK.z   // 'y' sits on the US 'z' position
        letters["z"] = VK.y   // 'z' sits on the US 'y' position
        for (ch, code) in letters {
            t[ch] = KeyStroke(keyCode: code)
            t[Character(ch.uppercased())] = KeyStroke(keyCode: code, shift: true)
        }

        // Accent (unshifted) / umlaut (shifted) keys, shared with French-Swiss.
        t["à"] = KeyStroke(keyCode: VK.quote)
        t["ä"] = KeyStroke(keyCode: VK.quote, shift: true)
        t["é"] = KeyStroke(keyCode: VK.semicolon)
        t["ö"] = KeyStroke(keyCode: VK.semicolon, shift: true)
        t["è"] = KeyStroke(keyCode: VK.leftBracket)
        t["ü"] = KeyStroke(keyCode: VK.leftBracket, shift: true)

        // Digit row and its Swiss shifted symbols. NOTE: `ç` is Shift+4.
        let digits: [(Character, Character, CGKeyCode)] = [
            ("1", "+", VK.n1), ("2", "\"", VK.n2), ("3", "*", VK.n3),
            ("4", "ç", VK.n4), ("5", "%", VK.n5), ("6", "&", VK.n6),
            ("7", "/", VK.n7), ("8", "(", VK.n8), ("9", ")", VK.n9),
            ("0", "=", VK.n0)
        ]
        for (base, shifted, code) in digits {
            t[base] = KeyStroke(keyCode: code)
            t[shifted] = KeyStroke(keyCode: code, shift: true)
        }

        // Comma / period and their shifted symbols (same as German).
        t[","] = KeyStroke(keyCode: VK.comma)
        t[";"] = KeyStroke(keyCode: VK.comma, shift: true)
        t["."] = KeyStroke(keyCode: VK.period)
        t[":"] = KeyStroke(keyCode: VK.period, shift: true)
        t["-"] = KeyStroke(keyCode: VK.slash)
        t["_"] = KeyStroke(keyCode: VK.slash, shift: true)

        // Option-layer symbols reused from Apple German positions.
        // TODO: verify Swiss German Option-layer positions on hardware
        t["{"] = KeyStroke(keyCode: VK.n8, option: true)
        t["["] = KeyStroke(keyCode: VK.n5, option: true)
        t["]"] = KeyStroke(keyCode: VK.n6, option: true)
        t["}"] = KeyStroke(keyCode: VK.n9, option: true)
        t["|"] = KeyStroke(keyCode: VK.n7, option: true)
        t["\\"] = KeyStroke(keyCode: VK.n7, shift: true, option: true)
        t["@"] = KeyStroke(keyCode: VK.l, option: true)

        // Whitespace.
        t[" "] = KeyStroke(keyCode: VK.space)
        t["\t"] = KeyStroke(keyCode: VK.tab)
        t["\n"] = KeyStroke(keyCode: VK.return)

        table = t
    }

    public func keyStroke(for character: Character) -> KeyStroke? {
        table[character]
    }
}
