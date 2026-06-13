import CoreGraphics

/// ANSI virtual key codes (`kVK_ANSI_*` / `kVK_*` from Carbon's `Events.h`).
///
/// These name *physical* key positions, not the characters printed on them.
/// Layout tables decide which character each position produces.
public enum VK {
    // Letter row positions (US-printed letters; reused/remapped per layout).
    public static let a: CGKeyCode = 0,  s: CGKeyCode = 1,  d: CGKeyCode = 2
    public static let f: CGKeyCode = 3,  h: CGKeyCode = 4,  g: CGKeyCode = 5
    public static let z: CGKeyCode = 6,  x: CGKeyCode = 7,  c: CGKeyCode = 8
    public static let v: CGKeyCode = 9,  b: CGKeyCode = 11, q: CGKeyCode = 12
    public static let w: CGKeyCode = 13, e: CGKeyCode = 14, r: CGKeyCode = 15
    public static let y: CGKeyCode = 16, t: CGKeyCode = 17, o: CGKeyCode = 31
    public static let u: CGKeyCode = 32, i: CGKeyCode = 34, p: CGKeyCode = 35
    public static let l: CGKeyCode = 37, j: CGKeyCode = 38, k: CGKeyCode = 40
    public static let n: CGKeyCode = 45, m: CGKeyCode = 46

    // Number row.
    public static let n1: CGKeyCode = 18, n2: CGKeyCode = 19, n3: CGKeyCode = 20
    public static let n4: CGKeyCode = 21, n5: CGKeyCode = 23, n6: CGKeyCode = 22
    public static let n7: CGKeyCode = 26, n8: CGKeyCode = 28, n9: CGKeyCode = 25
    public static let n0: CGKeyCode = 29

    // Punctuation positions.
    public static let equal: CGKeyCode = 24, minus: CGKeyCode = 27
    public static let rightBracket: CGKeyCode = 30, leftBracket: CGKeyCode = 33
    public static let quote: CGKeyCode = 39, semicolon: CGKeyCode = 41
    public static let backslash: CGKeyCode = 42, comma: CGKeyCode = 43
    public static let slash: CGKeyCode = 44, period: CGKeyCode = 47
    public static let grave: CGKeyCode = 50

    // Whitespace / control.
    public static let `return`: CGKeyCode = 36, tab: CGKeyCode = 48
    public static let space: CGKeyCode = 49

    /// US-position letter map, shared by layouts that keep QWERTY letters.
    public static let ansiLetters: [Character: CGKeyCode] = [
        "a": a, "b": b, "c": c, "d": d, "e": e, "f": f, "g": g, "h": h,
        "i": i, "j": j, "k": k, "l": l, "m": m, "n": n, "o": o, "p": p,
        "q": q, "r": r, "s": s, "t": t, "u": u, "v": v, "w": w, "x": x,
        "y": y, "z": z
    ]
}
