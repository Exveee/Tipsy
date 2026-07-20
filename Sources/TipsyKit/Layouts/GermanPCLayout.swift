import CoreGraphics

/// German (QWERTZ), **PC/Remote** layout — targets a remote host reached
/// through a scancode-forwarding KVM, not the local Mac.
///
/// ## PC vs. Apple
///
/// `GermanLayout` chooses key positions so **macOS's own German input
/// source** composes the right character locally — it presses left ⌥ for
/// AltGr symbols because that is what Apple's driver expects. This layout is
/// different: the KVM client translates each Mac virtual key code to a
/// physical key *position* (a browser DOM `code`, e.g. `"KeyQ"`,
/// `"Backquote"`) and forwards that position to the remote machine, which
/// then interprets it with its own PC German keyboard driver (the Windows/
/// Linux "German" layout, not Apple's). PC keyboards put AltGr on the
/// **right** Alt key, so every third-level symbol here uses
/// ``KeyStroke/rightOption`` — never `option` (left ⌥ is a plain modifier on
/// PC, not AltGr, and pressing it would not produce these characters).
///
/// ## ISO key caveat
///
/// `<`, `>`, and `|` live on `VK.section` (keycode 10), the ISO key
/// immediately right of the left Shift key — it maps to the browser DOM code
/// `"IntlBackslash"`. This key only exists on ISO keyboards; on a KVM client
/// running on ANSI-only hardware (no physical key sends `"IntlBackslash"`),
/// there may be no way to generate that DOM code, so these three characters
/// can fail to reach the remote even though the mapping below is correct for
/// an ISO-equipped client.
///
/// ## Coverage
///
/// Letters (Y/Z swap), umlauts + ß/`?`, digit row shifted symbols, comma/
/// period row, `+ * ~`, `# '`, the ISO `< > |` key, the AltGr row
/// (`@ € { [ ] } \ µ ² ³`), and the dead-key accents `^ ´ \`` (accent key +
/// SPACE) plus the direct (non-dead) `°`.
public struct GermanPCLayout: KeyboardLayout {
    public let id = "de-pc"
    public let displayName = "German (PC/Remote)"
    public let kind: LayoutKind = .pcScancode

    private let table: [Character: KeyStroke]

    /// Dead-key characters emitted as the literal symbol by pressing the
    /// accent key followed by SPACE on a PC German layout.
    private let deadKeys: [Character: [KeyStroke]] = [
        "^": [KeyStroke(keyCode: VK.grave), KeyStroke(keyCode: VK.space)],
        "´": [KeyStroke(keyCode: VK.equal), KeyStroke(keyCode: VK.space)],
        "`": [KeyStroke(keyCode: VK.equal, shift: true), KeyStroke(keyCode: VK.space)]
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

        // Umlauts and ß/? occupy ANSI punctuation positions.
        t["ü"] = KeyStroke(keyCode: VK.leftBracket)
        t["Ü"] = KeyStroke(keyCode: VK.leftBracket, shift: true)
        t["ö"] = KeyStroke(keyCode: VK.semicolon)
        t["Ö"] = KeyStroke(keyCode: VK.semicolon, shift: true)
        t["ä"] = KeyStroke(keyCode: VK.quote)
        t["Ä"] = KeyStroke(keyCode: VK.quote, shift: true)
        t["ß"] = KeyStroke(keyCode: VK.minus)
        t["?"] = KeyStroke(keyCode: VK.minus, shift: true)

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

        // `+ * ~` on the key right of ü. `~` is direct AltGr on PC German
        // (unlike Apple's dead-key `~`).
        t["+"] = KeyStroke(keyCode: VK.rightBracket)
        t["*"] = KeyStroke(keyCode: VK.rightBracket, shift: true)
        t["~"] = KeyStroke(keyCode: VK.rightBracket, rightOption: true)

        // `# '` on the key right of Ä (ANSI backslash position).
        t["#"] = KeyStroke(keyCode: VK.backslash)
        t["'"] = KeyStroke(keyCode: VK.backslash, shift: true)

        // ISO key left of left Shift: `< > |`. See the ISO caveat above.
        t["<"] = KeyStroke(keyCode: VK.section)
        t[">"] = KeyStroke(keyCode: VK.section, shift: true)
        t["|"] = KeyStroke(keyCode: VK.section, rightOption: true)

        // AltGr row (right Option on a PC layout).
        t["@"] = KeyStroke(keyCode: VK.q, rightOption: true)
        t["€"] = KeyStroke(keyCode: VK.e, rightOption: true)
        t["{"] = KeyStroke(keyCode: VK.n7, rightOption: true)
        t["["] = KeyStroke(keyCode: VK.n8, rightOption: true)
        t["]"] = KeyStroke(keyCode: VK.n9, rightOption: true)
        t["}"] = KeyStroke(keyCode: VK.n0, rightOption: true)
        t["\\"] = KeyStroke(keyCode: VK.minus, rightOption: true)
        t["µ"] = KeyStroke(keyCode: VK.m, rightOption: true)
        t["²"] = KeyStroke(keyCode: VK.n2, rightOption: true)
        t["³"] = KeyStroke(keyCode: VK.n3, rightOption: true)

        // `°` is a direct (non-dead) Shift on the accent key, unlike Apple's
        // ISO-section `°`; PC German puts it on Shift+`^` (grave position).
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
