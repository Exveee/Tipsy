import CoreGraphics

/// German (QWERTZ), Apple layout.
///
/// Groundwork coverage: letters (with Y/Z swap), umlauts, ß, digits and their
/// shifted symbols, comma/period, whitespace. AltGr (Option) symbols mapped:
/// `@ € { } [ ] | \` and the non-dead `°`. Dead-key accents `^ ´ \` ~` are
/// produced as multi-stroke sequences (dead accent + SPACE) via ``strokes(for:)``.
public struct GermanLayout: KeyboardLayout {
    public let id = "de"
    public let displayName = "German (QWERTZ)"

    private let table: [Character: KeyStroke]

    /// Dead-key characters emitted as the literal symbol by pressing the dead
    /// accent key followed by SPACE on the Apple German layout.
    private let deadKeys: [Character: [KeyStroke]] = [
        "^": [KeyStroke(keyCode: VK.grave), KeyStroke(keyCode: VK.space)],
        "´": [KeyStroke(keyCode: VK.equal), KeyStroke(keyCode: VK.space)],
        "`": [KeyStroke(keyCode: VK.equal, shift: true), KeyStroke(keyCode: VK.space)],
        "~": [KeyStroke(keyCode: VK.n, option: true), KeyStroke(keyCode: VK.space)]
    ]

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

        // Umlauts and ß occupy ANSI punctuation positions.
        t["ü"] = KeyStroke(keyCode: VK.leftBracket)
        t["Ü"] = KeyStroke(keyCode: VK.leftBracket, shift: true)
        t["ö"] = KeyStroke(keyCode: VK.semicolon)
        t["Ö"] = KeyStroke(keyCode: VK.semicolon, shift: true)
        t["ä"] = KeyStroke(keyCode: VK.quote)
        t["Ä"] = KeyStroke(keyCode: VK.quote, shift: true)
        t["ß"] = KeyStroke(keyCode: VK.minus)

        // Digit row and its shifted symbols (German legends).
        let digits: [(Character, Character, CGKeyCode)] = [
            ("1", "!", VK.n1), ("2", "\"", VK.n2), ("3", "§", VK.n3),
            ("4", "$", VK.n4), ("5", "%", VK.n5), ("6", "&", VK.n6),
            ("7", "/", VK.n7), ("8", "(", VK.n8), ("9", ")", VK.n9),
            ("0", "=", VK.n0)
        ]
        for (base, shifted, code) in digits {
            t[base] = KeyStroke(keyCode: code)
            t[shifted] = KeyStroke(keyCode: code, shift: true)
        }

        // Comma / period and their shifted symbols.
        t[","] = KeyStroke(keyCode: VK.comma)
        t[";"] = KeyStroke(keyCode: VK.comma, shift: true)
        t["."] = KeyStroke(keyCode: VK.period)
        t[":"] = KeyStroke(keyCode: VK.period, shift: true)
        t["-"] = KeyStroke(keyCode: VK.slash)
        t["_"] = KeyStroke(keyCode: VK.slash, shift: true)
        t["+"] = KeyStroke(keyCode: VK.rightBracket)
        t["*"] = KeyStroke(keyCode: VK.rightBracket, shift: true)

        // Common AltGr (Option) symbols on the Apple German layer.
        t["@"] = KeyStroke(keyCode: VK.l, option: true)
        t["€"] = KeyStroke(keyCode: VK.e, option: true)
        t["{"] = KeyStroke(keyCode: VK.n8, option: true)
        t["["] = KeyStroke(keyCode: VK.n5, option: true)
        t["]"] = KeyStroke(keyCode: VK.n6, option: true)
        t["}"] = KeyStroke(keyCode: VK.n9, option: true)
        t["|"] = KeyStroke(keyCode: VK.n7, option: true)
        t["\\"] = KeyStroke(keyCode: VK.n7, shift: true, option: true)
        t["°"] = KeyStroke(keyCode: VK.grave, shift: true)

        // Whitespace.
        t[" "] = KeyStroke(keyCode: VK.space)
        t["\t"] = KeyStroke(keyCode: VK.tab)
        t["\n"] = KeyStroke(keyCode: VK.return)

        table = t
    }

    public func keyStroke(for character: Character) -> KeyStroke? {
        table[character]
    }

    public func strokes(for character: Character) -> [KeyStroke]? {
        if let dead = deadKeys[character] {
            return dead
        }
        return keyStroke(for: character).map { [$0] }
    }
}
