import CoreGraphics

/// A single physical key press described layout-independently:
/// a virtual key code plus the modifier keys held while pressing it.
///
/// `option` and `rightOption` are distinct on purpose: locally macOS treats
/// both as ⌥, but remote hosts behind a KVM see real left/right Alt keys and
/// only produce AltGr symbols with the **right** one. Apple-local layouts use
/// `option`; PC-scancode layouts use `rightOption`.
public struct KeyStroke: Equatable, Sendable {
    public let keyCode: CGKeyCode
    public var shift: Bool = false
    public var option: Bool = false
    public var rightOption: Bool = false

    public init(keyCode: CGKeyCode, shift: Bool = false, option: Bool = false,
                rightOption: Bool = false) {
        self.keyCode = keyCode
        self.shift = shift
        self.option = option
        self.rightOption = rightOption
    }

    public var flags: CGEventFlags {
        var f = CGEventFlags()
        if shift { f.insert(.maskShift) }
        if option || rightOption { f.insert(.maskAlternate) }
        return f
    }
}
