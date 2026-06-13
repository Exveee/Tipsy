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
> in place; the menu bar app builds and runs, with Preferences, persisted
> settings, a global hotkey, and Unicode fallback. Layout coverage is being
> expanded.

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
   (`CGEvent` → `.cghidEventTap`), with a small inter-character delay (and
   optional jitter) so slow console targets don't drop input. Characters with
   no layout mapping are typed directly as Unicode when fallback is enabled.
4. **AppDelegate** is the menu bar UI: pick a layout, trigger typing, and a
   short countdown lets you focus the target window first. A global
   **Cmd+Shift+T** hotkey triggers typing without opening the menu, and a
   **Preferences** window exposes the tuning options, all persisted across
   launches.

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
│   │   ├── AppDelegate.swift     # Menu bar: layout picker + "Type Clipboard"
│   │   ├── Settings.swift        # UserDefaults-backed persisted settings
│   │   ├── PreferencesWindowController.swift  # Code-built preferences window
│   │   └── HotkeyManager.swift   # Global Cmd+Shift+T hotkey
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

**Done**
- [x] German Option (AltGr) layer: `@ € { } [ ] | \` mapped (`~` is a dead key,
      still unmapped).
- [x] UK British overrides: `£`, `@`/`"` swap, `#`/`~`, `€` (Option layer only
      partially verified).
- [x] Global hotkey (Cmd+Shift+T) to trigger typing without opening the menu.
- [x] Configurable typing speed and per-character jitter.
- [x] Preferences window (layout, delays, lead time, toggles) with persisted
      settings.
- [x] Unicode fallback (Unicode-direct event posting) for characters no layout maps.
- [x] Code signing + notarization workflow (`.github/workflows/release.yml`, on
      `v*` tags) — falls back to an ad-hoc build until the signing secrets are set.

**Planned**
- [ ] Full dead-key accent support (circumflex, acute, grave, tilde) via
      multi-stroke sequences; finish verifying the UK layout against BS 4822.
- [ ] Add Swiss German and other layouts behind the same `KeyboardLayout` protocol.
- [ ] Provision the release signing secrets (Developer ID + notarization) to ship
      a signed, notarized download.

---

## Documentation

More detail lives in [`docs/`](docs/):

- [Usage guide](docs/usage.md) — install, permissions, layouts, the hotkey, and
  the typical KVM/console workflow.
- [Architecture](docs/architecture.md) — component and data-flow overview,
  settings/hotkey/preferences, menu bar lifecycle, and concurrency notes.
- [Adding a layout](docs/adding-a-layout.md) — implement `KeyboardLayout`, build
  the `Character → KeyStroke` table, register it, and add tests.
- [Permissions & troubleshooting](docs/permissions-troubleshooting.md) — the
  Accessibility permission, re-adding after rebuilds, hotkey conflicts, and
  characters that don't type.

---

## License

TBD.
