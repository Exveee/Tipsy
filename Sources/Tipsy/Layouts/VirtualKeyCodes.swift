import CoreGraphics

/// ANSI virtual key codes (`kVK_ANSI_*` / `kVK_*` from Carbon's `Events.h`).
///
/// These name *physical* key positions, not the characters printed on them.
/// Layout tables decide which character each position produces.
enum VK {
    // Letter row positions (US-printed letters; reused/remapped per layout).
    static let a: CGKeyCode = 0,  s: CGKeyCode = 1,  d: CGKeyCode = 2
    static let f: CGKeyCode = 3,  h: CGKeyCode = 4,  g: CGKeyCode = 5
    static let z: CGKeyCode = 6,  x: CGKeyCode = 7,  c: CGKeyCode = 8
    static let v: CGKeyCode = 9,  b: CGKeyCode = 11, q: CGKeyCode = 12
    static let w: CGKeyCode = 13, e: CGKeyCode = 14, r: CGKeyCode = 15
    static let y: CGKeyCode = 16, t: CGKeyCode = 17, o: CGKeyCode = 31
    static let u: CGKeyCode = 32, i: CGKeyCode = 34, p: CGKeyCode = 35
    static let l: CGKeyCode = 37, j: CGKeyCode = 38, k: CGKeyCode = 40
    static let n: CGKeyCode = 45, m: CGKeyCode = 46

    // Number row.
    static let n1: CGKeyCode = 18, n2: CGKeyCode = 19, n3: CGKeyCode = 20
    static let n4: CGKeyCode = 21, n5: CGKeyCode = 23, n6: CGKeyCode = 22
    static let n7: CGKeyCode = 26, n8: CGKeyCode = 28, n9: CGKeyCode = 25
    static let n0: CGKeyCode = 29

    // Punctuation positions.
    static let equal: CGKeyCode = 24, minus: CGKeyCode = 27
    static let rightBracket: CGKeyCode = 30, leftBracket: CGKeyCode = 33
    static let quote: CGKeyCode = 39, semicolon: CGKeyCode = 41
    static let backslash: CGKeyCode = 42, comma: CGKeyCode = 43
    static let slash: CGKeyCode = 44, period: CGKeyCode = 47
    static let grave: CGKeyCode = 50

    // Whitespace / control.
    static let `return`: CGKeyCode = 36, tab: CGKeyCode = 48
    static let space: CGKeyCode = 49

    /// US-position letter map, shared by layouts that keep QWERTY letters.
    static let ansiLetters: [Character: CGKeyCode] = [
        "a": a, "b": b, "c": c, "d": d, "e": e, "f": f, "g": g, "h": h,
        "i": i, "j": j, "k": k, "l": l, "m": m, "n": n, "o": o, "p": p,
        "q": q, "r": r, "s": s, "t": t, "u": u, "v": v, "w": w, "x": x,
        "y": y, "z": z
    ]
}
