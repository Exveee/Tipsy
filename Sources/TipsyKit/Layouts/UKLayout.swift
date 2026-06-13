import CoreGraphics

/// UK English (QWERTY), Apple layout.
///
/// Groundwork coverage: starts from the US ANSI table and applies the British
/// differences (`@`/`"` swap, `£` on Shift+3, `#`/`~` key, `€` on Option+2).
/// TODO: verify the grave-key `¬` / `|` arrangement against BS 4822 before
/// mapping; remaining Option-layer symbols still to be confirmed.
public struct UKLayout: KeyboardLayout {
    public let id = "uk"
    public let displayName = "UK (QWERTY)"

    private let us = USLayout()
    private let overrides: [Character: KeyStroke]

    public init() {
        var o: [Character: KeyStroke] = [:]
        // British rows swap @ and " relative to US.
        o["\""] = KeyStroke(keyCode: VK.n2, shift: true)
        o["@"] = KeyStroke(keyCode: VK.quote, shift: true)
        // £ replaces US # on Shift+3.
        o["£"] = KeyStroke(keyCode: VK.n3, shift: true)
        // Dedicated #/~ key (ANSI backslash position on Apple UK).
        o["#"] = KeyStroke(keyCode: VK.backslash)
        o["~"] = KeyStroke(keyCode: VK.backslash, shift: true)
        // Euro sign on the Apple British Option layer.
        o["€"] = KeyStroke(keyCode: VK.n2, option: true)
        // TODO: ¬ and | live on the grave (`) key on Apple British, but the
        // exact ANSI/ISO arrangement is uncertain — verify against BS 4822
        // before mapping to avoid introducing wrong strokes.
        overrides = o
    }

    public func keyStroke(for character: Character) -> KeyStroke? {
        overrides[character] ?? us.keyStroke(for: character)
    }
}
