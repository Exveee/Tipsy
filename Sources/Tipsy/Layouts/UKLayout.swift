import CoreGraphics

/// UK English (QWERTY), Apple layout.
///
/// Groundwork coverage: starts from the US ANSI table and applies the British
/// differences (`@`/`"` swap, `£` on Shift+3, `#`/`~` key).
/// TODO: verify Option-layer symbols against BS 4822.
struct UKLayout: KeyboardLayout {
    let id = "uk"
    let displayName = "UK (QWERTY)"

    private let us = USLayout()
    private let overrides: [Character: KeyStroke]

    init() {
        var o: [Character: KeyStroke] = [:]
        // British rows swap @ and " relative to US.
        o["\""] = KeyStroke(keyCode: VK.n2, shift: true)
        o["@"] = KeyStroke(keyCode: VK.quote, shift: true)
        // £ replaces US # on Shift+3.
        o["£"] = KeyStroke(keyCode: VK.n3, shift: true)
        // Dedicated #/~ key (ANSI backslash position on Apple UK).
        o["#"] = KeyStroke(keyCode: VK.backslash)
        o["~"] = KeyStroke(keyCode: VK.backslash, shift: true)
        overrides = o
    }

    func keyStroke(for character: Character) -> KeyStroke? {
        overrides[character] ?? us.keyStroke(for: character)
    }
}
