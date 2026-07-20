// TipsyCheck — a tiny self-contained test runner.
//
// XCTest and swift-testing are unavailable with Command Line Tools only, so
// this executable target replaces them. It imports TipsyKit, runs the layout
// assertions, prints `✗ FAIL: ...` for each failure, and exits non-zero if any
// check failed. Run via `swift run TipsyCheck` (or `./Scripts/check.sh`).

import Carbon.HIToolbox
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

// MARK: - Intra-stroke pacing (#29 interEventDelay)

func countEvents(_ steps: [KeystrokeEngine.PostStep]) -> Int {
    steps.filter { if case .event = $0 { return true } else { return false } }.count
}
func countPauses(_ steps: [KeystrokeEngine.PostStep]) -> Int {
    steps.filter { if case .pause = $0 { return true } else { return false } }.count
}
func isEventStep(_ step: KeystrokeEngine.PostStep?) -> Bool {
    if case .event = step { return true } else { return false }
}

// A shifted stroke posts 4 events (Shift down, key down, key up, Shift up); with
// a delay set, 3 pauses sit strictly between them.
let pacedShift = KeystrokeEngine.postPlan(for: [KeyStroke(keyCode: VK.n1, shift: true)],
                                          interEventDelay: 0.005)
expectEqual(countEvents(pacedShift), 4)
expectEqual(countPauses(pacedShift), 3)
expectEqual(isEventStep(pacedShift.first), true, "plan must not start with a pause")
expectEqual(isEventStep(pacedShift.last), true, "plan must not end with a pause")
expectEqual(pacedShift == [
    .event(.init(keyCode: VK.shift, keyDown: true, flags: .maskShift)),
    .pause(0.005),
    .event(.init(keyCode: VK.n1, keyDown: true, flags: .maskShift)),
    .pause(0.005),
    .event(.init(keyCode: VK.n1, keyDown: false, flags: .maskShift)),
    .pause(0.005),
    .event(.init(keyCode: VK.shift, keyDown: false, flags: [])),
], true)

// interEventDelay 0 → no pauses at all: byte-identical event stream.
let unpacedShift = KeystrokeEngine.postPlan(for: [KeyStroke(keyCode: VK.n1, shift: true)],
                                            interEventDelay: 0)
expectEqual(countEvents(unpacedShift), 4)
expectEqual(countPauses(unpacedShift), 0)
expectEqual(unpacedShift.count, 4)

// A dead-key sequence (German `~` = ⌥n then space) is one plan spanning both
// strokes: 4 + 2 = 6 events, 5 pauses, including one between the two strokes.
let deadKeyStrokes = de.strokes(for: "~")!
let pacedDeadKey = KeystrokeEngine.postPlan(for: deadKeyStrokes, interEventDelay: 0.005)
expectEqual(countEvents(pacedDeadKey), 6)
expectEqual(countPauses(pacedDeadKey), 5)
expectEqual(isEventStep(pacedDeadKey.first), true)
expectEqual(isEventStep(pacedDeadKey.last), true)

// MARK: - KVM-safe config resolution (#30)

// A remote-console config never enables Unicode fallback, even when the stored
// user setting asks for it.
let remoteCfg = TypingConfig(profile: .remoteConsole, unicodeFallback: true)
expectEqual(remoteCfg.unicodeFallback, false)
// Local targets keep the requested fallback.
expectEqual(TypingConfig(profile: .localMac, unicodeFallback: true).unicodeFallback, true)
// Pacing defaults to the profile's delay, and an explicit value overrides it.
expectEqual(remoteCfg.interEventDelay, TargetProfile.remoteConsole.defaultInterEventDelay)
expectEqual(TypingConfig(profile: .remoteConsole, interEventDelay: 0.02).interEventDelay, 0.02)
expectEqual(TypingConfig(profile: .localMac).interEventDelay, 0)

// MARK: - SkippedReport aggregation (#30)

var report = SkippedReport()
expectEqual(report.isEmpty, true)
report.record("本", at: 3)
report.record("x", at: 5)
report.record("本", at: 7)
expectEqual(report.isEmpty, false)
expectEqual(report.entries.count, 2, "duplicates aggregate into one entry")
expectEqual(report.totalCount, 3)
expectEqual(report.uniqueCharacters, ["本", "x"], "unique, first-seen order")
expectEqual(report.entries[0].count, 2)
expectEqual(report.entries[0].firstIndex, 3, "first index is preserved")
expectEqual(report.entries[1].firstIndex, 5)

// MARK: - DynamicLocalLayout self-consistency

// This layout reverse-maps through whatever input source is active on the CI
// machine, so we assert *properties* (round-trip, universal chars) rather than
// layout-specific expectations, which vary per machine.

/// Grabs the current source's Unicode key layout, if any (CJK input methods
/// expose none). Kept alive for the caller via the returned CFData box.
func currentKeyLayout() -> (data: CFData, ptr: UnsafePointer<UCKeyboardLayout>)? {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
          let layoutPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
        return nil
    }
    let data = Unmanaged<CFData>.fromOpaque(layoutPtr).takeUnretainedValue()
    guard let bytes = CFDataGetBytePtr(data) else { return nil }
    return (data, UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self))
}

/// Forward-translates a stroke sequence back into the string it should type,
/// threading `deadKeyState` so a `[deadAccent, space]` pair resolves to the
/// spacing accent — the inverse of what DynamicLocalLayout records.
func forwardTranslate(_ strokes: [KeyStroke], _ keyLayout: UnsafePointer<UCKeyboardLayout>) -> String {
    let keyboardType = UInt32(LMGetKbdType())
    var deadKeyState: UInt32 = 0
    var output = ""
    for stroke in strokes {
        var state: UInt32 = 0
        if stroke.shift { state |= UInt32(shiftKey >> 8) }
        if stroke.option || stroke.rightOption { state |= UInt32(optionKey >> 8) }
        var chars = [UniChar](repeating: 0, count: 8)
        var length = 0
        let status = UCKeyTranslate(keyLayout, UInt16(stroke.keyCode), UInt16(kUCKeyActionDown),
                                    state, keyboardType, OptionBits(0),
                                    &deadKeyState, chars.count, &length, &chars)
        if status == noErr, length > 0 {
            output += String(utf16CodeUnits: chars, count: length)
        }
    }
    return output
}

let dynamic = DynamicLocalLayout()
expectEqual(dynamic.id, "dynamic")
expectEqual(dynamic.kind, .appleLocal)

if let (data, keyLayout) = currentKeyLayout() {
    withExtendedLifetime(data) {
        // Round-trip: every character this machine's source maps must forward-
        // translate back to itself. Probe printable ASCII plus common accented
        // Latin so dead-key sequences are exercised where the source has them.
        var candidates = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        candidates += Array(" !\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~")
        candidates += Array("äöüßàáâãèéêìíîòóôùúûñçÄÖÜ€£°´`^~")
        for c in candidates {
            if let strokes = dynamic.strokes(for: c) {
                let produced = forwardTranslate(strokes, keyLayout)
                expectEqual(produced, String(c), "dynamic round-trip for U+\(String(format: "%04X", c.unicodeScalars.first!.value))")
            }
        }

        // Universal characters that survive any Latin source with layout data.
        expectEqual(dynamic.strokes(for: " ") != nil, true, "space resolves")
        expectEqual(dynamic.strokes(for: "\n") != nil, true, "newline resolves")
        for digit in "0123456789" {
            expectEqual(dynamic.keyStroke(for: digit) != nil, true, "digit \(digit) resolves")
        }
    }
} else {
    // Input methods (CJK) expose no layout data: the map is empty by design and
    // every character falls through to the engine's own handling.
    expectNil(dynamic.keyStroke(for: "a"), "no layout data => empty map")
}

// MARK: - InputSourceMatch (pure logic)

// Exact prefix match.
expectEqual(InputSourceMatch.matches(inputSourceID: "com.apple.keylayout.German", layoutID: "de"), true)
// Longer source ID still matches by prefix.
expectEqual(InputSourceMatch.matches(inputSourceID: "com.apple.keylayout.German.foo", layoutID: "de"), true)
// Mismatch: US source while layout expects German.
expectEqual(InputSourceMatch.matches(inputSourceID: "com.apple.keylayout.US", layoutID: "de"), false)
// US layout accepts either US or ABC.
expectEqual(InputSourceMatch.matches(inputSourceID: "com.apple.keylayout.ABC", layoutID: "us"), true)
// Empty-list wildcard: the dynamic layout matches any source.
expectEqual(InputSourceMatch.matches(inputSourceID: "com.apple.inputmethod.SCIM.ITABC", layoutID: "dynamic"), true)
// Unknown layout id => empty expectation list => matches anything.
expectEqual(InputSourceMatch.expectedPrefixes(for: "zz-nope"), [])
expectEqual(InputSourceMatch.matches(inputSourceID: "com.apple.keylayout.Whatever", layoutID: "zz-nope"), true)
// PC variants reuse the local prefixes.
expectEqual(InputSourceMatch.expectedPrefixes(for: "de-pc"), ["com.apple.keylayout.German"])
// Swiss German prefix.
expectEqual(InputSourceMatch.matches(inputSourceID: "com.apple.keylayout.SwissGerman", layoutID: "ch-de"), true)

// MARK: - Canary string (#36)

// The canonical QA payload from docs/kvm-test-matrix.md. Every character in it
// must resolve on the German PC layout, so a regression in any mapped special
// character fails here before it reaches a real KVM test.
let canary = """
0123456789
abcdefghijklmnopqrstuvwxyz
ABCDEFGHIJKLMNOPQRSTUVWXYZ
ä ö ü Ä Ö Ü ß
@ € { } [ ] | \\ ~ ^ ° § " ' < > - _ + * # ; :
"""
for character in canary {
    if dePC.strokes(for: character) == nil {
        expectEqual("unmapped: \(character)", "mapped", "canary char must resolve on GermanPCLayout")
    }
}
expectEqual(canary.allSatisfy { dePC.strokes(for: $0) != nil }, true, "full canary resolves on de-pc")

// The ASCII subset of the canary must resolve on the US PC layout.
let asciiCanary = canary.filter { $0.isASCII }
expectEqual(asciiCanary.allSatisfy { usPC.strokes(for: $0) != nil }, true, "ASCII canary resolves on us-pc")

// Typographic input normalized for a remote console becomes fully typeable on
// the German PC layout — the chain that prevents stray characters on a KVM.
let typographic = "\u{201E}Hi\u{201C} \u{2018}x\u{2019} 2013\u{2013}2024\u{00A0}km\r\nEnde\u{2026}"
let normalizedCanary = TextNormalization.normalize(typographic, options: .remoteConsole)
expectEqual(normalizedCanary.allSatisfy { dePC.strokes(for: $0) != nil }, true, "normalized typographic text resolves on de-pc")
expectEqual(normalizedCanary, "\"Hi\" 'x' 2013-2024 km\nEnde...")

// MARK: - Summary

print("\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
