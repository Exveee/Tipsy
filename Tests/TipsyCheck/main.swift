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

// MARK: - PC layouts

// German (PC/Remote): id, displayName, kind.
let dePC = GermanPCLayout()
expectEqual(dePC.id, "de-pc")
expectEqual(dePC.displayName, "German (PC/Remote)")
expectEqual(dePC.kind, LayoutKind.pcScancode)

// Letters: US positions with Y/Z swapped, Shift for uppercase.
expectEqual(dePC.keyStroke(for: "a"), KeyStroke(keyCode: VK.a))
expectEqual(dePC.keyStroke(for: "A"), KeyStroke(keyCode: VK.a, shift: true))
expectEqual(dePC.keyStroke(for: "z"), KeyStroke(keyCode: VK.y))
expectEqual(dePC.keyStroke(for: "Z"), KeyStroke(keyCode: VK.y, shift: true))
expectEqual(dePC.keyStroke(for: "y"), KeyStroke(keyCode: VK.z))
expectEqual(dePC.keyStroke(for: "Y"), KeyStroke(keyCode: VK.z, shift: true))

// Umlauts and ß/?.
expectEqual(dePC.keyStroke(for: "ü"), KeyStroke(keyCode: VK.leftBracket))
expectEqual(dePC.keyStroke(for: "Ü"), KeyStroke(keyCode: VK.leftBracket, shift: true))
expectEqual(dePC.keyStroke(for: "ö"), KeyStroke(keyCode: VK.semicolon))
expectEqual(dePC.keyStroke(for: "Ö"), KeyStroke(keyCode: VK.semicolon, shift: true))
expectEqual(dePC.keyStroke(for: "ä"), KeyStroke(keyCode: VK.quote))
expectEqual(dePC.keyStroke(for: "Ä"), KeyStroke(keyCode: VK.quote, shift: true))
expectEqual(dePC.keyStroke(for: "ß"), KeyStroke(keyCode: VK.minus))
expectEqual(dePC.keyStroke(for: "?"), KeyStroke(keyCode: VK.minus, shift: true))

// Digit row shifted symbols.
expectEqual(dePC.keyStroke(for: "1"), KeyStroke(keyCode: VK.n1))
expectEqual(dePC.keyStroke(for: "!"), KeyStroke(keyCode: VK.n1, shift: true))
expectEqual(dePC.keyStroke(for: "2"), KeyStroke(keyCode: VK.n2))
expectEqual(dePC.keyStroke(for: "\""), KeyStroke(keyCode: VK.n2, shift: true))
expectEqual(dePC.keyStroke(for: "3"), KeyStroke(keyCode: VK.n3))
expectEqual(dePC.keyStroke(for: "§"), KeyStroke(keyCode: VK.n3, shift: true))
expectEqual(dePC.keyStroke(for: "4"), KeyStroke(keyCode: VK.n4))
expectEqual(dePC.keyStroke(for: "$"), KeyStroke(keyCode: VK.n4, shift: true))
expectEqual(dePC.keyStroke(for: "5"), KeyStroke(keyCode: VK.n5))
expectEqual(dePC.keyStroke(for: "%"), KeyStroke(keyCode: VK.n5, shift: true))
expectEqual(dePC.keyStroke(for: "6"), KeyStroke(keyCode: VK.n6))
expectEqual(dePC.keyStroke(for: "&"), KeyStroke(keyCode: VK.n6, shift: true))
expectEqual(dePC.keyStroke(for: "7"), KeyStroke(keyCode: VK.n7))
expectEqual(dePC.keyStroke(for: "/"), KeyStroke(keyCode: VK.n7, shift: true))
expectEqual(dePC.keyStroke(for: "8"), KeyStroke(keyCode: VK.n8))
expectEqual(dePC.keyStroke(for: "("), KeyStroke(keyCode: VK.n8, shift: true))
expectEqual(dePC.keyStroke(for: "9"), KeyStroke(keyCode: VK.n9))
expectEqual(dePC.keyStroke(for: ")"), KeyStroke(keyCode: VK.n9, shift: true))
expectEqual(dePC.keyStroke(for: "0"), KeyStroke(keyCode: VK.n0))
expectEqual(dePC.keyStroke(for: "="), KeyStroke(keyCode: VK.n0, shift: true))

// Comma/period row.
expectEqual(dePC.keyStroke(for: ","), KeyStroke(keyCode: VK.comma))
expectEqual(dePC.keyStroke(for: ";"), KeyStroke(keyCode: VK.comma, shift: true))
expectEqual(dePC.keyStroke(for: "."), KeyStroke(keyCode: VK.period))
expectEqual(dePC.keyStroke(for: ":"), KeyStroke(keyCode: VK.period, shift: true))
expectEqual(dePC.keyStroke(for: "-"), KeyStroke(keyCode: VK.slash))
expectEqual(dePC.keyStroke(for: "_"), KeyStroke(keyCode: VK.slash, shift: true))

// `+ * ~` — `~` is direct AltGr on PC German, not a dead key.
expectEqual(dePC.keyStroke(for: "+"), KeyStroke(keyCode: VK.rightBracket))
expectEqual(dePC.keyStroke(for: "*"), KeyStroke(keyCode: VK.rightBracket, shift: true))
expectEqual(dePC.keyStroke(for: "~"), KeyStroke(keyCode: VK.rightBracket, rightOption: true))

// `# '`.
expectEqual(dePC.keyStroke(for: "#"), KeyStroke(keyCode: VK.backslash))
expectEqual(dePC.keyStroke(for: "'"), KeyStroke(keyCode: VK.backslash, shift: true))

// ISO key: `< > |`.
expectEqual(dePC.keyStroke(for: "<"), KeyStroke(keyCode: VK.section))
expectEqual(dePC.keyStroke(for: ">"), KeyStroke(keyCode: VK.section, shift: true))
expectEqual(dePC.keyStroke(for: "|"), KeyStroke(keyCode: VK.section, rightOption: true))

// AltGr row.
expectEqual(dePC.keyStroke(for: "@"), KeyStroke(keyCode: VK.q, rightOption: true))
expectEqual(dePC.keyStroke(for: "€"), KeyStroke(keyCode: VK.e, rightOption: true))
expectEqual(dePC.keyStroke(for: "{"), KeyStroke(keyCode: VK.n7, rightOption: true))
expectEqual(dePC.keyStroke(for: "["), KeyStroke(keyCode: VK.n8, rightOption: true))
expectEqual(dePC.keyStroke(for: "]"), KeyStroke(keyCode: VK.n9, rightOption: true))
expectEqual(dePC.keyStroke(for: "}"), KeyStroke(keyCode: VK.n0, rightOption: true))
expectEqual(dePC.keyStroke(for: "\\"), KeyStroke(keyCode: VK.minus, rightOption: true))
expectEqual(dePC.keyStroke(for: "µ"), KeyStroke(keyCode: VK.m, rightOption: true))
expectEqual(dePC.keyStroke(for: "²"), KeyStroke(keyCode: VK.n2, rightOption: true))
expectEqual(dePC.keyStroke(for: "³"), KeyStroke(keyCode: VK.n3, rightOption: true))

// Dead keys: accent key then SPACE.
expectEqual(dePC.strokes(for: "^"),
            [KeyStroke(keyCode: VK.grave), KeyStroke(keyCode: VK.space)])
expectEqual(dePC.strokes(for: "´"),
            [KeyStroke(keyCode: VK.equal), KeyStroke(keyCode: VK.space)])
expectEqual(dePC.strokes(for: "`"),
            [KeyStroke(keyCode: VK.equal, shift: true), KeyStroke(keyCode: VK.space)])
// `°` is direct (single stroke), not a dead-key sequence.
expectEqual(dePC.keyStroke(for: "°"), KeyStroke(keyCode: VK.grave, shift: true))
expectEqual(dePC.strokes(for: "°"), [KeyStroke(keyCode: VK.grave, shift: true)])

// Whitespace.
expectEqual(dePC.keyStroke(for: " "), KeyStroke(keyCode: VK.space))
expectEqual(dePC.keyStroke(for: "\t"), KeyStroke(keyCode: VK.tab))
expectEqual(dePC.keyStroke(for: "\n"), KeyStroke(keyCode: VK.return))

// German (PC/Remote) is registered in the layout registry.
expectEqual(Layouts.all.contains { $0.id == "de-pc" }, true)

// US (PC/Remote): id, displayName, kind.
let usPC = USPCLayout()
expectEqual(usPC.id, "us-pc")
expectEqual(usPC.displayName, "US (PC/Remote)")
expectEqual(usPC.kind, LayoutKind.pcScancode)

// Every printable ASCII character resolves to a key stroke.
for scalar in UInt8(0x20)...UInt8(0x7E) {
    let ch = Character(UnicodeScalar(scalar))
    expectEqual(usPC.keyStroke(for: ch) != nil, true, "USPCLayout missing '\(ch)'")
}

// Spot-check letters and shifted digit-row symbols.
expectEqual(usPC.keyStroke(for: "a"), KeyStroke(keyCode: VK.a))
expectEqual(usPC.keyStroke(for: "A"), KeyStroke(keyCode: VK.a, shift: true))
expectEqual(usPC.keyStroke(for: "z"), KeyStroke(keyCode: VK.z))
expectEqual(usPC.keyStroke(for: "1"), KeyStroke(keyCode: VK.n1))
expectEqual(usPC.keyStroke(for: "!"), KeyStroke(keyCode: VK.n1, shift: true))
expectEqual(usPC.keyStroke(for: "2"), KeyStroke(keyCode: VK.n2))
expectEqual(usPC.keyStroke(for: "@"), KeyStroke(keyCode: VK.n2, shift: true))

// Spot-check punctuation, including the shifted symbols.
expectEqual(usPC.keyStroke(for: "-"), KeyStroke(keyCode: VK.minus))
expectEqual(usPC.keyStroke(for: "_"), KeyStroke(keyCode: VK.minus, shift: true))
expectEqual(usPC.keyStroke(for: "["), KeyStroke(keyCode: VK.leftBracket))
expectEqual(usPC.keyStroke(for: "{"), KeyStroke(keyCode: VK.leftBracket, shift: true))
expectEqual(usPC.keyStroke(for: "`"), KeyStroke(keyCode: VK.grave))
expectEqual(usPC.keyStroke(for: "~"), KeyStroke(keyCode: VK.grave, shift: true))

// Whitespace.
expectEqual(usPC.keyStroke(for: " "), KeyStroke(keyCode: VK.space))
expectEqual(usPC.keyStroke(for: "\t"), KeyStroke(keyCode: VK.tab))
expectEqual(usPC.keyStroke(for: "\n"), KeyStroke(keyCode: VK.return))

// A US PC keyboard has no AltGr layer: Apple-only extras stay unmapped.
expectNil(usPC.keyStroke(for: "§"))
expectNil(usPC.keyStroke(for: "€"))

// US (PC/Remote) is registered in the layout registry.
expectEqual(Layouts.all.contains { $0.id == "us-pc" }, true)

// MARK: - Summary

print("\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
