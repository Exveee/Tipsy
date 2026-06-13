import AppKit

/// Draws Tipsy's glyph: a clipboard with a text caret — "clipboard, typed".
/// Used for the menu bar status item as a monochrome template image.
enum TipsyIcon {

    /// A template menu bar image (auto-tinted by macOS for light/dark).
    static func statusItemImage() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            drawGlyph(scale: size.width / 18.0)
            return true
        }
        image.isTemplate = true
        return image
    }

    /// Draws the 18×18 glyph in the current context using the fill color
    /// (black, so template tinting applies via alpha coverage).
    private static func drawGlyph(scale: CGFloat) {
        let ink = NSColor.black

        // Clipboard board outline.
        let board = NSBezierPath(roundedRect: NSRect(x: 3.5, y: 1.5, width: 11, height: 14),
                                 xRadius: 2, yRadius: 2)
        board.lineWidth = 1.4
        ink.setStroke()
        board.stroke()

        // Clip tab at the top.
        let clip = NSBezierPath(roundedRect: NSRect(x: 6.5, y: 13.5, width: 5, height: 3),
                                xRadius: 1, yRadius: 1)
        ink.setFill()
        clip.fill()

        // Two "typed" text lines.
        ink.withAlphaComponent(0.85).setFill()
        NSBezierPath(rect: NSRect(x: 5.5, y: 9, width: 5, height: 1.2)).fill()
        NSBezierPath(rect: NSRect(x: 5.5, y: 6.4, width: 7, height: 1.2)).fill()

        // Blinking-style caret after the first line.
        ink.setFill()
        NSBezierPath(rect: NSRect(x: 11, y: 8.3, width: 1.3, height: 3)).fill()
    }
}
