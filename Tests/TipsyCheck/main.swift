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

// MARK: - Text normalization

// One table per rule: (input, expected output) with `.remoteConsole` (all
// rules on), matching the issue's per-rule requirements.
let smartQuoteCases: [(String, String)] = [
    ("\u{201E}hi\u{201C}", "\"hi\""),  // „hi“
    ("\u{201D}hi\u{201F}", "\"hi\""),  // ”hi‟
    ("\u{00BB}hi\u{00AB}", "\"hi\""),  // »hi«
    ("\u{2039}hi\u{203A}", "\"hi\""),  // ‹hi›
    ("\u{2018}hi\u{2019}", "'hi'"),    // ‘hi’
    ("\u{201A}hi\u{201B}", "'hi'"),    // ‚hi‛
    ("5\u{2032}", "5'"),               // 5′ (prime)
]
for (input, expected) in smartQuoteCases {
    expectEqual(TextNormalization.normalize(input, options: .remoteConsole), expected, "smartQuotes: \(input)")
}

let dashCases: [(String, String)] = [
    ("2013\u{2013}2024", "2013-2024"),  // en dash
    ("wait\u{2014}what", "wait-what"),  // em dash
    ("a\u{2012}b", "a-b"),              // figure dash
    ("a\u{2015}b", "a-b"),              // horizontal bar
    ("a-b", "a-b"),                     // ASCII hyphen untouched
]
for (input, expected) in dashCases {
    expectEqual(TextNormalization.normalize(input, options: .remoteConsole), expected, "dashes: \(input)")
}

let spaceCases: [(String, String)] = [
    ("a\u{00A0}b", "a b"),  // NBSP
    ("a\u{202F}b", "a b"),  // narrow NBSP
    ("a\u{2009}b", "a b"),  // thin space
    ("a\u{2002}b", "a b"),  // en space
    ("a\u{2003}b", "a b"),  // em space
    ("a\u{3000}b", "a b"),  // ideographic space
]
for (input, expected) in spaceCases {
    expectEqual(TextNormalization.normalize(input, options: .remoteConsole), expected, "spaces: \(input)")
}

let invisibleCases: [(String, String)] = [
    ("a\u{00AD}b", "ab"),  // soft hyphen
    ("a\u{200B}b", "ab"),  // zero-width space
    ("a\u{200D}b", "ab"),  // zero-width joiner
    ("a\u{200C}b", "ab"),  // zero-width non-joiner
    ("\u{FEFF}ab", "ab"),  // BOM
    ("a\u{2060}b", "ab"),  // word joiner
]
for (input, expected) in invisibleCases {
    expectEqual(TextNormalization.normalize(input, options: .remoteConsole), expected, "invisibles: \(input)")
}

let lineEndingCases: [(String, String)] = [
    ("a\r\nb", "a\nb"),  // CRLF
    ("a\rb", "a\nb"),    // lone CR
    ("a\nb", "a\nb"),    // LF already, untouched
]
for (input, expected) in lineEndingCases {
    expectEqual(TextNormalization.normalize(input, options: .remoteConsole), expected, "lineEndings: \(input)")
}

expectEqual(TextNormalization.normalize("wait\u{2026}", options: .remoteConsole), "wait...", "ellipsis")

// Presets.
let fancyText = "\u{201C}wait\u{2026}\u{201D}\u{2014}really\u{00A0}soon\u{200B}\r\n"
expectEqual(TextNormalization.normalize(fancyText, options: .remoteConsole),
            "\"wait...\"-really soon\n",
            "remoteConsole preset applies every rule")
expectEqual(TextNormalization.normalize(fancyText, options: .localMac),
            "\u{201C}wait\u{2026}\u{201D}\u{2014}really\u{00A0}soon\n",
            "localMac preset only strips invisibles and normalizes line endings")

// Idempotency: normalizing already-normalized text must be a no-op, for both presets.
for options in [NormalizationOptions.remoteConsole, .localMac] {
    let once = TextNormalization.normalize(fancyText, options: options)
    let twice = TextNormalization.normalize(once, options: options)
    expectEqual(twice, once, "idempotency")
}

// Disabled rules leave matching text unchanged.
var noneEnabled = NormalizationOptions()
noneEnabled.smartQuotes = false
noneEnabled.dashes = false
noneEnabled.spaces = false
noneEnabled.invisibles = false
noneEnabled.lineEndings = false
noneEnabled.ellipsis = false
expectEqual(TextNormalization.normalize(fancyText, options: noneEnabled), fancyText, "all rules disabled: no-op")

// MARK: - Summary

print("\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
