import XCTest
@testable import Tipsy

final class LayoutTests: XCTestCase {

    func testUSLowerAndUpper() {
        let us = USLayout()
        let a = us.keyStroke(for: "a")
        XCTAssertEqual(a, KeyStroke(keyCode: VK.a))
        let A = us.keyStroke(for: "A")
        XCTAssertEqual(A, KeyStroke(keyCode: VK.a, shift: true))
    }

    func testUSShiftedDigit() {
        XCTAssertEqual(USLayout().keyStroke(for: "!"),
                       KeyStroke(keyCode: VK.n1, shift: true))
    }

    func testGermanSwapsYandZ() {
        let de = GermanLayout()
        // On QWERTZ the 'z' character sits on the US 'y' position and vice versa.
        XCTAssertEqual(de.keyStroke(for: "z"), KeyStroke(keyCode: VK.y))
        XCTAssertEqual(de.keyStroke(for: "y"), KeyStroke(keyCode: VK.z))
    }

    func testGermanUmlaut() {
        XCTAssertEqual(GermanLayout().keyStroke(for: "ä"),
                       KeyStroke(keyCode: VK.quote))
    }

    func testUKOverridesPound() {
        XCTAssertEqual(UKLayout().keyStroke(for: "£"),
                       KeyStroke(keyCode: VK.n3, shift: true))
    }

    func testUnsupportedCharacterReturnsNil() {
        XCTAssertNil(USLayout().keyStroke(for: "本"))
    }
}
