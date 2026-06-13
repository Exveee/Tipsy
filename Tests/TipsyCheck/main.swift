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

// MARK: - Summary

print("\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
