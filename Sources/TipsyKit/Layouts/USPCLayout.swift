import CoreGraphics

/// US English (ANSI QWERTY), **PC/Remote** layout — targets a remote host
/// reached through a scancode-forwarding KVM, not the local Mac.
///
/// Position-for-position this is identical to `USLayout`: a real PC "United
/// States - QWERTY" driver produces the same characters at the same ANSI
/// positions macOS does, so there is no PC-vs-Apple divergence to correct
/// here (unlike `GermanPCLayout`, whose `°`/`~`/ISO-key positions differ from
/// Apple's German layout). The only functional difference from `USLayout` is
/// that this layout has **no AltGr layer**: a stock US PC keyboard has no
/// third-level symbols, so there is nothing to map with
/// ``KeyStroke/rightOption`` here, and Apple-only extras like `§` are
/// intentionally left unmapped (`§` is not a printable-ASCII character and
/// has no PC-US position at all).
///
/// Covers full printable ASCII: letters, digit row + shifted symbols,
/// punctuation, and whitespace.
public struct USPCLayout: KeyboardLayout {
    public let id = "us-pc"
    public let displayName = "US (PC/Remote)"
    public let kind: LayoutKind = .pcScancode

    private let table: [Character: KeyStroke]

    public init() {
        var t: [Character: KeyStroke] = [:]

        // Letters: lowercase unshifted, uppercase shifted.
        for (ch, code) in VK.ansiLetters {
            t[ch] = KeyStroke(keyCode: code)
            t[Character(ch.uppercased())] = KeyStroke(keyCode: code, shift: true)
        }

        // Digit row and its shifted symbols.
        let digits: [(Character, Character, CGKeyCode)] = [
            ("1", "!", VK.n1), ("2", "@", VK.n2), ("3", "#", VK.n3),
            ("4", "$", VK.n4), ("5", "%", VK.n5), ("6", "^", VK.n6),
            ("7", "&", VK.n7), ("8", "*", VK.n8), ("9", "(", VK.n9),
            ("0", ")", VK.n0)
        ]
        for (base, shifted, code) in digits {
            t[base] = KeyStroke(keyCode: code)
            t[shifted] = KeyStroke(keyCode: code, shift: true)
        }

        // Punctuation: (base, shifted, position).
        let punct: [(Character, Character, CGKeyCode)] = [
            ("-", "_", VK.minus), ("=", "+", VK.equal),
            ("[", "{", VK.leftBracket), ("]", "}", VK.rightBracket),
            ("\\", "|", VK.backslash), (";", ":", VK.semicolon),
            ("'", "\"", VK.quote), (",", "<", VK.comma),
            (".", ">", VK.period), ("/", "?", VK.slash),
            ("`", "~", VK.grave)
        ]
        for (base, shifted, code) in punct {
            t[base] = KeyStroke(keyCode: code)
            t[shifted] = KeyStroke(keyCode: code, shift: true)
        }

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
