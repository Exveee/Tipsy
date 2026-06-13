# Architecture

Tipsy is a macOS menu bar accessory app (`LSUIElement`) built with Swift
Package Manager — there is no Xcode project. The executable bootstraps an
`NSApplication` in `.accessory` mode (no Dock icon, no main window) and hands
control to `AppDelegate`.

```
Sources/Tipsy/
├── main.swift                # NSApplication bootstrap (accessory policy)
├── App/
│   ├── AppDelegate.swift      # Menu bar UI + typing trigger
│   ├── Settings.swift         # UserDefaults-backed settings
│   ├── PreferencesWindowController.swift
│   └── HotkeyManager.swift    # Global Cmd+Shift+T hotkey
├── Core/
│   ├── ClipboardReader.swift  # NSPasteboard text
│   ├── KeyStroke.swift        # Key code + modifier value type
│   └── KeystrokeEngine.swift  # Quartz CGEvent synthesis
├── Layouts/
│   ├── KeyboardLayout.swift   # Protocol + Layouts registry
│   ├── VirtualKeyCodes.swift  # ANSI virtual key-code constants (VK)
│   ├── USLayout.swift / GermanLayout.swift / UKLayout.swift
└── Permissions/
    └── AccessibilityManager.swift
```

## Data flow

Typing the clipboard is a four-stage pipeline:

```
┌────────────┐  text   ┌───────────────┐ KeyStroke ┌────────────────┐ CGEvent
│ Clipboard  │ ──────▶ │ KeyboardLayout │ ────────▶ │ KeystrokeEngine│ ──────▶ focused app
│(NSPasteb.) │         │  (char → key)  │           │  (Quartz post) │
└────────────┘         └───────────────┘           └────────────────┘
```

1. **`ClipboardReader.text()`** returns the plain-text contents of
   `NSPasteboard.general`, or `nil` if the clipboard holds no string.
2. **`KeyboardLayout.keyStroke(for:)`** maps each `Character` to a
   layout-independent **`KeyStroke`** — a virtual key code plus `shift` /
   `option` flags — or returns `nil` if the layout has no mapping for that
   character.
3. **`KeystrokeEngine.type(_:using:)`** walks the string character by
   character. For each character it either posts the resolved `KeyStroke`, or
   (when `unicodeFallback` is on) types the character directly via its UTF-16
   code units, or records it as skipped. It returns the array of characters it
   could not type so the caller can warn the user.
4. Each stroke is posted as a key-down / key-up `CGEvent` pair to
   `.cghidEventTap`, so the focused application sees genuine hardware-like
   keystrokes — the path that works where clipboard paste is blocked.

### `KeyStroke`

```swift
struct KeyStroke: Equatable {
    let keyCode: CGKeyCode
    var shift: Bool = false
    var option: Bool = false
    var flags: CGEventFlags { /* shift → .maskShift, option → .maskAlternate */ }
}
```

`KeyStroke` is the boundary between the layout tables (pure data) and the event
system. Because layouts are pure lookup tables that produce `KeyStroke` values,
they are trivially unit-testable without touching Quartz at all
(`Tests/TipsyTests/LayoutTests.swift`).

## Menu bar lifecycle

`AppDelegate.applicationDidFinishLaunching` runs the startup sequence:

1. `AccessibilityManager.ensureTrusted(prompt: true)` — checks the
   Accessibility permission and, if missing, shows the system prompt.
2. `applySettings()` — loads persisted values into the engine
   (`characterDelay`, `jitter`, `unicodeFallback`), the `leadTime`, and the
   `activeLayout`.
3. `buildStatusItem()` — creates the `NSStatusItem` (the `⌨︎` menu bar icon)
   and builds its menu.
4. Wires `hotkey.onTrigger` to `typeClipboard()` and installs the global
   hotkey if enabled.

The menu contains: **Type Clipboard** (shows the current lead time), a radio
list of layouts (checkmark on the active one), **Preferences…**, and **Quit**.
Selecting a layout writes `Settings.layoutID` and rebuilds the menu.

### Triggering a type

Both the menu item and the global hotkey call `typeClipboard()`:

1. Read the clipboard; bail with an alert if empty.
2. Verify `AccessibilityManager.isTrusted`; bail with an alert if not.
3. Capture the active layout, then after `leadTime` seconds dispatch
   `engine.type(text, using: layout)` on a background queue.

The **lead time** is the deliberate pause that lets the user click into the
target window (a KVM/console field) before typing begins.

## Settings and Preferences

`Settings` is a `@MainActor enum` over `UserDefaults.standard`. Each property
reads and writes a single key on access, so values stay in sync with disk and
survive relaunches; defaults are returned for keys that were never written.

| Key | Default | Meaning |
|-----|---------|---------|
| `tipsy.layoutID` | first layout (`de`) | Active keyboard layout |
| `tipsy.characterDelay` | `0.012` | Seconds between characters |
| `tipsy.jitter` | `0` | Random ± variation on each delay |
| `tipsy.unicodeFallback` | `true` | Type unmapped chars as Unicode |
| `tipsy.leadTime` | `3` | Countdown before typing starts |
| `tipsy.hotkeyEnabled` | `true` | Global Cmd+Shift+T active |

`PreferencesWindowController` is a code-built (no nib) window with a layout
popup, sliders for character delay (0–0.2s), jitter (0–0.1s), and lead time
(0–10s), plus checkboxes for Unicode fallback and the global hotkey. Each
control writes straight through to `Settings` and calls `onChange`, which makes
`AppDelegate` re-apply settings, refresh the hotkey state, and rebuild the menu
live.

## Global hotkey

`HotkeyManager` registers a fixed **Cmd+Shift+T** combo using `NSEvent`
monitors rather than a Carbon hot-key, so no extra entitlement is needed:

- A **global** monitor delivers the event while Tipsy is in the background.
- A **local** monitor covers the case where Tipsy itself is the key app (and
  returns the event so it is not swallowed for Tipsy's own UI).

Global monitors require the Accessibility permission, which the app already
holds for keystroke synthesis. Note the global monitor observes but does not
*consume* the event — other apps still receive Cmd+Shift+T (see
[permissions-troubleshooting.md](permissions-troubleshooting.md)).

## Concurrency notes

- **UI is `@MainActor`.** `AppDelegate`, `Settings`,
  `PreferencesWindowController`, and `HotkeyManager` are all main-actor
  isolated, matching AppKit's threading rules.
- **The engine is `@unchecked Sendable`.** `KeystrokeEngine` is marked
  `@unchecked Sendable` so it can be captured and run on a background dispatch
  queue from `typeClipboard()`. The typing loop calls `Thread.sleep` for the
  inter-character delay, so it must run off the main thread to avoid freezing
  the UI. The `@unchecked` is a deliberate assertion: the engine is only ever
  invoked from one typing run at a time, so its mutable tuning properties are
  not concurrently mutated during a run.
- `AccessibilityManager.ensureTrusted` passes the literal string
  `"AXTrustedCheckOptionPrompt"` rather than the imported global constant,
  which Swift 6's concurrency checking rejects.
