# Adding a keyboard layout

A layout in Tipsy is a pure lookup table that answers one question: *which
physical key (plus modifiers) types this character?* Adding one means
implementing the `KeyboardLayout` protocol, filling a `Character → KeyStroke`
table, registering it, and adding unit tests. No event-system code is involved.

## 1. Implement `KeyboardLayout`

The layout engine lives in the `TipsyKit` library, so its public API is what
the app and the `TipsyCheck` test runner import. The protocol
(`Sources/TipsyKit/Layouts/KeyboardLayout.swift`):

```swift
public protocol KeyboardLayout: Sendable {
    var id: String { get }            // stable settings id, e.g. "ch"
    var displayName: String { get }   // menu title, e.g. "Swiss German"
    func keyStroke(for character: Character) -> KeyStroke?
}
```

Create a new file under `Sources/TipsyKit/Layouts/`, e.g.
`SwissGermanLayout.swift`. Because it is part of the library's public API, mark
the type, its `init`, and the protocol members `public`. Build the table once in
`init` and look it up in `keyStroke(for:)`:

```swift
import CoreGraphics

public struct SwissGermanLayout: KeyboardLayout {
    public let id = "ch"
    public let displayName = "Swiss German"

    private let table: [Character: KeyStroke]

    public init() {
        var t: [Character: KeyStroke] = [:]
        // ... fill the table (see below) ...
        table = t
    }

    public func keyStroke(for character: Character) -> KeyStroke? {
        table[character]
    }
}
```

## 2. Build the `Character → KeyStroke` table

A `KeyStroke` is a **virtual key code** (a physical key *position*) plus the
`shift` / `option` modifiers held while pressing it:

```swift
public struct KeyStroke: Equatable, Sendable {
    public let keyCode: CGKeyCode
    public var shift: Bool = false
    public var option: Bool = false
}
```

Use the `VK` constants from `VirtualKeyCodes.swift` for key positions — never
raw integers. `VK` names *physical* positions (US-printed legends), not the
characters your layout produces; the table is where you decide what each
position types. Example for a single key that produces three characters:

```swift
// Unshifted, shifted, and Option (AltGr) on one physical key.
t["é"] = KeyStroke(keyCode: VK.quote)
t["ö"] = KeyStroke(keyCode: VK.quote, shift: true)
t["{"] = KeyStroke(keyCode: VK.quote, option: true)
```

### Tips

- **Letters that keep QWERTY positions** can reuse `VK.ansiLetters` — iterate
  it to add lowercase (unshifted) and uppercase (shifted) in one loop, as
  `USLayout` and `GermanLayout` do.
- **Swapped keys** (e.g. QWERTZ's Y/Z) are just two reassignments before the
  loop — see `GermanLayout`.
- **Building on an existing layout:** to start from US and apply only national
  differences, hold a `USLayout()` instance and an `overrides` dictionary,
  then `overrides[character] ?? us.keyStroke(for: character)`. This is exactly
  what `UKLayout` does.
- **Always map whitespace:** `" "` → `VK.space`, `"\t"` → `VK.tab`,
  `"\n"` → `VK.return`.
- If a key position you need has no `VK` constant yet, add it to
  `VirtualKeyCodes.swift` (a separate concern — coordinate before editing
  shared files).

## 3. Handle Shift and Option

- **Shift** for the upper legend on a key: `KeyStroke(keyCode: ..., shift: true)`.
- **Option / AltGr** for the third (Apple Option) layer:
  `KeyStroke(keyCode: ..., option: true)`.
- Both together when a symbol needs Shift+Option:
  `KeyStroke(keyCode: ..., shift: true, option: true)` (e.g. German `\`).

The modifiers map to `CGEventFlags` (`.maskShift`, `.maskAlternate`)
automatically via `KeyStroke.flags`.

## 4. Dead keys are not yet supported

Tipsy posts exactly one key-down/key-up pair per character, so it **cannot**
type characters that require a dead-key sequence (e.g. Apple German `~` =
Option+N then Space, or accent composition like `^`, `´`, `` ` ``). Leave those
characters **unmapped** (return `nil`) rather than guessing a single stroke —
returning `nil` lets the Unicode fallback handle them and keeps the table
honest. Document any such gaps in the layout's doc comment, as `GermanLayout`
does for `~`.

## 5. Register the layout

Add an instance to the registry in `KeyboardLayout.swift`:

```swift
public enum Layouts {
    public static let all: [KeyboardLayout] = [
        GermanLayout(), USLayout(), UKLayout(), SwissGermanLayout()
    ]
}
```

The first entry is the default. The new layout automatically appears in the
menu bar layout picker and the Preferences popup — no UI changes needed.

## 6. Add checks to the test runner

Tipsy has no XCTest target — both XCTest and swift-testing are unavailable with
Command Line Tools only. Instead, `Tests/TipsyCheck/main.swift` is a plain
executable that imports `TipsyKit` and asserts `KeyStroke` values directly (no
event system), so checks run fast and locally. Add cases there using the
`expectEqual` / `expectNil` helpers. Cover:

- a plain letter (lower and upper case),
- each national difference / override that distinguishes the layout,
- any Option-layer symbol,
- and at least one deliberately unmapped character (assert `nil`) so dead-key
  gaps stay intentional:

```swift
expectEqual(SwissGermanLayout().keyStroke(for: "ö"),
            KeyStroke(keyCode: VK.quote, shift: true))

expectNil(SwissGermanLayout().keyStroke(for: "~"))
```

Run them with `./Scripts/check.sh` (or `swift run TipsyCheck` directly). The
runner prints `✗ FAIL: …` for each failed check, a `N passed, M failed`
summary, and exits non-zero if anything failed.
