// TipsyCheck — a tiny self-contained test runner.
//
// XCTest and swift-testing are unavailable with Command Line Tools only, so
// this executable target replaces them. It imports TipsyKit, runs the layout
// assertions, prints `✗ FAIL: ...` for each failure, and exits non-zero if any
// check failed. Run via `swift run TipsyCheck` (or `./Scripts/check.sh`).

import Foundation
import TipsyKit

// MARK: - Minimal assertion harness

var passed = 0
var failed = 0

@MainActor
func expectEqual<T: Equatable>(_ actual: T,
                               _ expected: T,
                               _ message: String = "",
                               file: StaticString = #file,
                               line: UInt = #line) {
    if actual == expected {
        passed += 1
    } else {
        failed += 1
        let suffix = message.isEmpty ? "" : " — \(message)"
        print("✗ FAIL: \(actual) != \(expected)\(suffix)  [\(file):\(line)]")
    }
}

@MainActor
func expectEqual(_ actual: [KeyStroke]?,
                 _ expected: [KeyStroke]?,
                 _ message: String = "",
                 file: StaticString = #file,
                 line: UInt = #line) {
    if actual == expected {
        passed += 1
    } else {
        failed += 1
        let suffix = message.isEmpty ? "" : " — \(message)"
        print("✗ FAIL: \(String(describing: actual)) != \(String(describing: expected))\(suffix)  [\(file):\(line)]")
    }
}

@MainActor
func expectNil<T>(_ actual: T?,
                  _ message: String = "",
                  file: StaticString = #file,
                  line: UInt = #line) {
    if actual == nil {
        passed += 1
    } else {
        failed += 1
        let suffix = message.isEmpty ? "" : " — \(message)"
        print("✗ FAIL: expected nil but got \(actual!)\(suffix)  [\(file):\(line)]")
    }
}

// MARK: - Layout assertions (ported from the old XCTest LayoutTests)

// US lower and upper.
let us = USLayout()
expectEqual(us.keyStroke(for: "a"), KeyStroke(keyCode: VK.a))
expectEqual(us.keyStroke(for: "A"), KeyStroke(keyCode: VK.a, shift: true))

// US shifted digit `!`.
expectEqual(USLayout().keyStroke(for: "!"), KeyStroke(keyCode: VK.n1, shift: true))

// German Y/Z swap: on QWERTZ 'z' sits on the US 'y' position and vice versa.
let de = GermanLayout()
expectEqual(de.keyStroke(for: "z"), KeyStroke(keyCode: VK.y))
expectEqual(de.keyStroke(for: "y"), KeyStroke(keyCode: VK.z))

// German umlaut `ä`.
expectEqual(GermanLayout().keyStroke(for: "ä"), KeyStroke(keyCode: VK.quote))

// German Option `{ [ ] }`.
expectEqual(de.keyStroke(for: "{"), KeyStroke(keyCode: VK.n8, option: true))
expectEqual(de.keyStroke(for: "["), KeyStroke(keyCode: VK.n5, option: true))
expectEqual(de.keyStroke(for: "]"), KeyStroke(keyCode: VK.n6, option: true))
expectEqual(de.keyStroke(for: "}"), KeyStroke(keyCode: VK.n9, option: true))

// German Option `|` and `\`.
expectEqual(de.keyStroke(for: "|"), KeyStroke(keyCode: VK.n7, option: true))
expectEqual(de.keyStroke(for: "\\"), KeyStroke(keyCode: VK.n7, shift: true, option: true))

// German `~` is a dead key and must not resolve to a single stroke.
expectNil(GermanLayout().keyStroke(for: "~"))

// German keeps `@` and `€`.
expectEqual(de.keyStroke(for: "@"), KeyStroke(keyCode: VK.l, option: true))
expectEqual(de.keyStroke(for: "€"), KeyStroke(keyCode: VK.e, option: true))

// UK `£`.
expectEqual(UKLayout().keyStroke(for: "£"), KeyStroke(keyCode: VK.n3, shift: true))

// UK `€` = Option+2.
expectEqual(UKLayout().keyStroke(for: "€"), KeyStroke(keyCode: VK.n2, option: true))

// Unsupported character `本` returns nil.
expectNil(USLayout().keyStroke(for: "本"))

// MARK: - Multi-stroke / dead keys (German)

expectEqual(de.strokes(for: "~"),
            [KeyStroke(keyCode: VK.n, option: true), KeyStroke(keyCode: VK.space)])
// `^` dead key sits on the ISO section key (10), not grave (50 = `<>|` on ISO).
expectEqual(de.strokes(for: "^"),
            [KeyStroke(keyCode: VK.section), KeyStroke(keyCode: VK.space)])
// `°` = Shift on the same ISO section key.
expectEqual(de.keyStroke(for: "°"), KeyStroke(keyCode: VK.section, shift: true))
// Default single-stroke path still works through strokes(for:).
expectEqual(de.strokes(for: "a"), [KeyStroke(keyCode: VK.a)])

// MARK: - Swiss German layout

let ch = SwissGermanLayout()
expectEqual(ch.keyStroke(for: "ä"), KeyStroke(keyCode: VK.quote, shift: true))
expectEqual(ch.keyStroke(for: "à"), KeyStroke(keyCode: VK.quote))
expectEqual(ch.keyStroke(for: "é"), KeyStroke(keyCode: VK.semicolon))
expectEqual(ch.keyStroke(for: "ç"), KeyStroke(keyCode: VK.n4, shift: true))
// QWERTZ swap: 'z' sits on the US 'y' position.
expectEqual(ch.keyStroke(for: "z"), KeyStroke(keyCode: VK.y))

// Swiss German is registered in the layout registry.
expectEqual(Layouts.all.contains { $0.id == "ch-de" }, true)

// MARK: - Modifier plan (#28 right Option / AltGr)

// A right-Option stroke presses key code 61 and never left Option (58).
let altgrPlan = KeystrokeEngine.modifierPlan(for: KeyStroke(keyCode: VK.q, rightOption: true))
expectEqual(altgrPlan.contains { $0.keyCode == VK.rightOption }, true, "AltGr must use key 61")
expectEqual(altgrPlan.contains { $0.keyCode == 61 }, true)
expectEqual(altgrPlan.contains { $0.keyCode == VK.option }, false, "AltGr must never fall back to 58")
expectEqual(altgrPlan.contains { $0.keyCode == 58 }, false)
// Right Option pressed then released, both carrying the ⌥ flag on press.
expectEqual(altgrPlan, [
    KeystrokeEngine.KeyEvent(keyCode: VK.rightOption, keyDown: true, flags: .maskAlternate),
    KeystrokeEngine.KeyEvent(keyCode: VK.rightOption, keyDown: false, flags: []),
])

// A plain Shift stroke keeps today's semantics: press Shift, release Shift with
// flags cleared, nothing else.
let shiftPlan = KeystrokeEngine.modifierPlan(for: KeyStroke(keyCode: VK.n1, shift: true))
expectEqual(shiftPlan, [
    KeystrokeEngine.KeyEvent(keyCode: VK.shift, keyDown: true, flags: .maskShift),
    KeystrokeEngine.KeyEvent(keyCode: VK.shift, keyDown: false, flags: []),
])

// Shift+Option releases Option first (leaving Shift held), then Shift — the
// pre-existing progressive-flag-clearing behavior.
let shiftOptPlan = KeystrokeEngine.modifierPlan(for: KeyStroke(keyCode: VK.n7, shift: true, option: true))
expectEqual(shiftOptPlan, [
    KeystrokeEngine.KeyEvent(keyCode: VK.shift, keyDown: true, flags: [.maskShift, .maskAlternate]),
    KeystrokeEngine.KeyEvent(keyCode: VK.option, keyDown: true, flags: [.maskShift, .maskAlternate]),
    KeystrokeEngine.KeyEvent(keyCode: VK.option, keyDown: false, flags: .maskShift),
    KeystrokeEngine.KeyEvent(keyCode: VK.shift, keyDown: false, flags: []),
])

// An unmodified stroke needs no modifier events at all.
expectEqual(KeystrokeEngine.modifierPlan(for: KeyStroke(keyCode: VK.a)), [])

// MARK: - Summary

print("\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
