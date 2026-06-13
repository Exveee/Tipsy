import CoreGraphics

/// US English (ANSI QWERTY). Reference layout — fully mapped for printable ASCII.
public struct USLayout: KeyboardLayout {
    public let id = "us"
    public let displayName = "US (QWERTY)"

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
