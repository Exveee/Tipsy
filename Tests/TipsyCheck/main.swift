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

// MARK: - Summary

print("\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
