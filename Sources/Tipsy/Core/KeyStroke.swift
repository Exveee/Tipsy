import CoreGraphics

/// A single physical key press described layout-independently:
/// a virtual key code plus the modifier keys held while pressing it.
struct KeyStroke: Equatable {
    let keyCode: CGKeyCode
    var shift: Bool = false
    var option: Bool = false

    var flags: CGEventFlags {
        var f = CGEventFlags()
        if shift { f.insert(.maskShift) }
        if option { f.insert(.maskAlternate) }
        return f
    }
}
