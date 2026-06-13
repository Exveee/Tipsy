import CoreGraphics

/// A single physical key press described layout-independently:
/// a virtual key code plus the modifier keys held while pressing it.
public struct KeyStroke: Equatable, Sendable {
    public let keyCode: CGKeyCode
    public var shift: Bool = false
    public var option: Bool = false

    public init(keyCode: CGKeyCode, shift: Bool = false, option: Bool = false) {
        self.keyCode = keyCode
        self.shift = shift
        self.option = option
    }

    public var flags: CGEventFlags {
        var f = CGEventFlags()
        if shift { f.insert(.maskShift) }
        if option { f.insert(.maskAlternate) }
        return f
    }
}
