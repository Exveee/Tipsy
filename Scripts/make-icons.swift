#!/usr/bin/env swift
//
// Generates the Tipsy app icon as a .iconset of PNGs.
// Run: swift Scripts/make-icons.swift [outputDir]  (then bundle.sh runs iconutil)
//   outputDir: where to write AppIcon.iconset (also via $TIPSY_DIST; default "dist")
//
// Draws the brand glyph — a clipboard with an amber text caret on an
// indigo→violet squircle — at every required size with CoreGraphics/AppKit.

import AppKit

/// Renders the icon at pixel size `S` into a bitmap.
func drawIcon(_ S: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: S, height: S)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Background squircle with a slight margin and a vertical gradient.
    let margin = S * 0.08
    let bgRect = NSRect(x: margin, y: margin, width: S - 2 * margin, height: S - 2 * margin)
    let bg = NSBezierPath(roundedRect: bgRect, xRadius: bgRect.width * 0.225,
                          yRadius: bgRect.width * 0.225)
    let gradient = NSGradient(starting: NSColor(srgbRed: 0.55, green: 0.36, blue: 0.96, alpha: 1),
                              ending: NSColor(srgbRed: 0.39, green: 0.40, blue: 0.95, alpha: 1))!
    gradient.draw(in: bg, angle: -90)

    // Clipboard board (white, rounded), centered.
    let bw = S * 0.46, bh = S * 0.56
    let boardRect = NSRect(x: (S - bw) / 2, y: (S - bh) / 2 - S * 0.02, width: bw, height: bh)
    let board = NSBezierPath(roundedRect: boardRect, xRadius: S * 0.05, yRadius: S * 0.05)
    NSColor.white.setFill()
    board.fill()

    // Clip tab at the top.
    let cw = bw * 0.42, ch = bh * 0.12
    let clipRect = NSRect(x: (S - cw) / 2, y: boardRect.maxY - ch * 0.55, width: cw, height: ch)
    NSColor(srgbRed: 0.42, green: 0.45, blue: 0.95, alpha: 1).setFill()
    NSBezierPath(roundedRect: clipRect, xRadius: ch * 0.4, yRadius: ch * 0.4).fill()

    // Two "typed" text lines.
    let lineColor = NSColor(srgbRed: 0.79, green: 0.83, blue: 0.88, alpha: 1)
    lineColor.setFill()
    let lx = boardRect.minX + bw * 0.16
    let lh = bh * 0.07
    NSBezierPath(roundedRect: NSRect(x: lx, y: boardRect.midY + bh * 0.04,
                                     width: bw * 0.44, height: lh),
                 xRadius: lh / 2, yRadius: lh / 2).fill()
    NSBezierPath(roundedRect: NSRect(x: lx, y: boardRect.midY - bh * 0.10,
                                     width: bw * 0.60, height: lh),
                 xRadius: lh / 2, yRadius: lh / 2).fill()

    // Amber text caret after the first line.
    NSColor(srgbRed: 0.96, green: 0.62, blue: 0.07, alpha: 1).setFill()
    let caretH = bh * 0.20
    NSBezierPath(roundedRect: NSRect(x: lx + bw * 0.50,
                                     y: boardRect.midY + bh * 0.005,
                                     width: bw * 0.06, height: caretH),
                 xRadius: bw * 0.03, yRadius: bw * 0.03).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

// Output directory resolution (most explicit wins):
//   1. first CLI argument, 2. $TIPSY_DIST, 3. "dist" relative to CWD.
// The .iconset is always written as <distDir>/AppIcon.iconset.
let distDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : (ProcessInfo.processInfo.environment["TIPSY_DIST"] ?? "dist")
let outDir = URL(fileURLWithPath: distDir).appendingPathComponent("AppIcon.iconset").path
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

// (point size, scale) → filename, per Apple's iconset convention.
let variants: [(pt: Int, scale: Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2),
    (256, 1), (256, 2), (512, 1), (512, 2)
]
for v in variants {
    let px = v.pt * v.scale
    let rep = drawIcon(CGFloat(px))
    guard let data = rep.representation(using: .png, properties: [:]) else { continue }
    let suffix = v.scale == 2 ? "@2x" : ""
    let name = "icon_\(v.pt)x\(v.pt)\(suffix).png"
    try! data.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
}
print("Wrote \(outDir) (\(variants.count) PNGs)")
