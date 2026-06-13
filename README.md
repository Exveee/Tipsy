# Tipsy

**Type your clipboard.** A macOS menu bar utility that simulates real keyboard
input from the contents of your clipboard — for systems where pasting is
blocked (KVM consoles, remote IPMI/iDRAC/iLO sessions, locked-down VMs,
hypervisor web consoles, …).

Tipsy reads the clipboard, then posts genuine key-down/key-up events through
the macOS event system so the target sees physical-like keystrokes. Output
characters are mapped through a selectable **keyboard layout**, so what you copy
is what the remote machine actually receives — even when its layout differs from
yours.

> Status: **early groundwork (v0.1.0)**. Core architecture and layout engine are
> in place; the menu bar app builds and runs. Layout coverage is being expanded.

---

## Why

Copy/paste fails on many out-of-band management surfaces:

- KVM-over-IP and BMC consoles (iDRAC, iLO, IPMI, PiKVM)
- Hypervisor web consoles (Proxmox noVNC, VMware, Hyper-V)
- Hardened or air-gapped VMs that disable the paste channel

The reliable fallback is *typing*. Tipsy automates that: paste-as-keystrokes,
with the correct national layout, at a console-friendly speed.

---

## How it works

```
┌────────────┐   text    ┌──────────────┐   KeyStroke   ┌────────────────┐  CGEvent
│ Clipboard  │ ────────▶ │ KeyboardLayout│ ───────────▶ │ KeystrokeEngine│ ────────▶ focused app
│ (NSPasteb.)│           │  (char → key) │              │  (Quartz post) │
└────────────┘           └──────────────┘              └────────────────┘
```

1. **ClipboardReader** pulls plain text from `NSPasteboard`.
2. **KeyboardLayout** maps each `Character` to a layout-independent
   **`KeyStroke`** (virtual key code + Shift/Option modifiers).
3. **KeystrokeEngine** posts each stroke as Quartz keyboard events
   (`CGEvent` → `.cghidEventTap`), with a small inter-character delay so
   slow console targets don't drop input.
4. **AppDelegate** is the menu bar UI: pick a layout, trigger typing, and a
   short countdown lets you focus the target window first.

Synthesizing input requires the **Accessibility** permission
(`AXIsProcessTrusted`); `AccessibilityManager` checks for it and prompts.

---

## Project layout

```
Tipsy/
├── Package.swift                 # SwiftPM manifest (executable + test target)
├── Sources/Tipsy/
│   ├── main.swift                # NSApplication bootstrap (menu bar accessory)
│   ├── App/
│   │   └── AppDelegate.swift     # Menu bar: layout picker + "Type Clipboard"
│   ├── Core/
│   │   ├── KeyStroke.swift       # Key code + modifier value type
│   │   ├── KeystrokeEngine.swift # Quartz event synthesis
│   │   └── ClipboardReader.swift # NSPasteboard access
│   ├── Layouts/
│   │   ├── KeyboardLayout.swift  # Protocol + Layouts registry
│   │   ├── VirtualKeyCodes.swift # ANSI virtual key-code constants
│   │   ├── USLayout.swift        # US QWERTY (reference, full ASCII)
│   │   ├── GermanLayout.swift    # DE QWERTZ (Y/Z swap, umlauts, ß)
│   │   └── UKLayout.swift        # UK QWERTY (£, @/" swap, #/~)
│   └── Permissions/
│       └── AccessibilityManager.swift
├── Tests/TipsyTests/             # Layout mapping unit tests (XCTest)
├── Resources/Info.plist          # Bundle metadata (LSUIElement menu bar app)
├── Scripts/bundle.sh             # Build → assemble Tipsy.app (no Xcode needed)
└── .github/workflows/ci.yml      # Build + test on macOS runner
```

### Shipped layouts

| ID   | Layout            | Coverage                                        |
|------|-------------------|-------------------------------------------------|
| `de` | German (QWERTZ)   | Letters, umlauts, ß, digits, common AltGr — *expanding* |
| `us` | US (QWERTY)       | Full printable ASCII                            |
| `uk` | UK (QWERTY)       | US base + British overrides — *to verify*       |

---

## Build & run

Requires macOS 13+ and the Swift 6 toolchain (Command Line Tools is enough to
build; full Xcode is needed only to run the `XCTest` suite locally — CI runs it).

```bash
# Build the executable
swift build

# Assemble a runnable Tipsy.app (ad-hoc signed) into ./dist
./Scripts/bundle.sh release
open dist/Tipsy.app
```

On first run, grant **System Settings → Privacy & Security → Accessibility**
permission to Tipsy, then use the menu bar **⌨︎** icon → *Type Clipboard*.

---

## Infrastructure & roadmap

**Toolchain**
- Swift Package Manager (no Xcode project checked in — keeps the repo lean and
  CI simple). `Scripts/bundle.sh` produces the `.app` bundle directly from SPM
  output, so a GUI app ships without an Xcode project.

**CI** (`.github/workflows/ci.yml`)
- `swift build` + `swift test` on the `macos-14` runner for every push/PR.

**Planned**
- [ ] Complete German AltGr layer and dead-key accents; verify UK against BS 4822.
- [ ] Add Swiss German and other layouts behind the same `KeyboardLayout` protocol.
- [ ] Global hotkey to trigger typing without opening the menu.
- [ ] Configurable typing speed and per-character jitter.
- [ ] Preferences window (default layout, delay) with persisted settings.
- [ ] Code signing + notarization in CI for distributable releases.
- [ ] Unicode fallback (Unicode-direct event posting) for characters no layout maps.

---

## License

TBD.
