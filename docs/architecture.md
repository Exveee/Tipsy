# Architecture

Tipsy is a macOS menu bar accessory app (`LSUIElement`) built with Swift
Package Manager — there is no Xcode project. The reusable logic lives in a
`TipsyKit` library; the `Tipsy` executable target holds only the AppKit UI and
imports `TipsyKit`, and a `TipsyCheck` executable target imports `TipsyKit` to
run the tests. The app executable bootstraps an `NSApplication` in `.accessory`
mode (no Dock icon, no main window) and hands control to `AppDelegate`.

```
Sources/
├── TipsyKit/                  # Reusable library (public API)
│   ├── Core/
│   │   ├── ClipboardReader.swift  # NSPasteboard text
│   │   ├── KeyStroke.swift        # Key code + modifier value type
│   │   └── KeystrokeEngine.swift  # Quartz CGEvent synthesis
│   ├── Layouts/
│   │   ├── KeyboardLayout.swift   # Protocol + Layouts registry
│   │   ├── VirtualKeyCodes.swift  # ANSI virtual key-code constants (VK)
│   │   ├── USLayout.swift / GermanLayout.swift / UKLayout.swift
│   │   └── SwissGermanLayout.swift
│   └── Permissions/
│       └── AccessibilityManager.swift
└── Tipsy/                     # Menu bar app executable (imports TipsyKit)
    ├── main.swift                # NSApplication bootstrap (accessory policy)
    └── App/
        ├── AppDelegate.swift      # Menu bar UI + typing trigger
        ├── Settings.swift         # UserDefaults-backed settings
        ├── PreferencesWindowController.swift
        ├── HotkeyManager.swift    # Configurable global hotkey (default ⌘⇧V)
        ├── HotkeyFormat.swift     # Hotkey ↔ display string / menu key equivalent
        ├── PasteCueSound.swift    # Synthesized cue motifs (AVAudioEngine)
        ├── LoginItem.swift        # Start-at-login via SMAppService
        └── TipsyIcon.swift        # Code-drawn menu bar template glyph
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
   character. **`strokes(for:)`** returns a *sequence* of `KeyStroke`s, so a
   single character can require multiple presses — used for **dead keys** (e.g.
   German `~` = Option+n then Space). Its default implementation wraps the
   single `keyStroke(for:)` result.
3. **`KeystrokeEngine.type(_:using:)`** walks the string character by
   character. For each character it posts the whole `strokes(for:)` sequence,
   or (when `unicodeFallback` is on) types the character directly via its UTF-16
   code units, or records it as skipped. A per-character delay (plus optional
   `jitter`) paces the output. It returns the array of characters it could not
   type so the caller can warn the user.
4. Each stroke is posted as a key-down / key-up `CGEvent` pair to
   `.cghidEventTap`, so the focused application sees genuine hardware-like
   keystrokes — the path that works where clipboard paste is blocked.

### `KeyStroke`

```swift
public struct KeyStroke: Equatable, Sendable {
    public let keyCode: CGKeyCode
    public var shift: Bool = false
    public var option: Bool = false
    public var flags: CGEventFlags { /* shift → .maskShift, option → .maskAlternate */ }
}
```

`KeyStroke` is the boundary between the layout tables (pure data) and the event
system. Because layouts are pure lookup tables that produce `KeyStroke` values,
they are trivially testable without touching Quartz at all — the `TipsyCheck`
runner (`Tests/TipsyCheck/main.swift`) imports `TipsyKit` and asserts these
values directly.

## Menu bar lifecycle

`AppDelegate.applicationDidFinishLaunching` runs the startup sequence:

1. `AccessibilityManager.ensureTrusted(prompt: true)` — checks the
   Accessibility permission and, if missing, shows the system prompt.
2. `applySettings()` — loads persisted values into the engine
   (`characterDelay`, `jitter`, `unicodeFallback`), the `leadTime`, and the
   `activeLayout`.
3. `buildStatusItem()` — creates the `NSStatusItem` with the clipboard glyph
   from `TipsyIcon.statusItemImage()` (a code-drawn monochrome template image,
   auto-tinted for light/dark) and builds its menu.
4. Wires `hotkey.onTrigger` to `typeClipboard()` and installs the global
   hotkey if enabled.

The menu contains: **Type Clipboard** (shows the current lead time; its keyboard
accelerator mirrors the configured hotkey via `HotkeyFormat`), a **Target** radio
pair (`localMac` / `remoteConsole`), a radio list of layouts *filtered to the
active target's `layoutKind`* (checkmark on the active one), **Preferences…**, and
**Quit**. Selecting a layout writes `Settings.layoutID`; selecting a target writes
`Settings.targetProfile` and, when the current layout's kind no longer fits,
auto-selects the first matching layout via `Layouts.resolvedLayoutID(for:current:)`
and persists it. Both rebuild the menu.

### Triggering a type

Both the menu item and the global hotkey call `typeClipboard()`:

1. Verify `AccessibilityManager.isTrusted`; bail with an alert if not.
2. Read the clipboard; bail with an alert if empty.
3. Normalize typographic characters (when enabled) with the active profile's
   preset — `.remoteConsole` (all rules) or `.localMac` (only invisibles and
   line endings).
4. For `.localMac`, if the active macOS input source doesn't match the selected
   layout (`InputSourceMatch`), show a "may not match" alert *before* the
   countdown with **Continue anyway** / **Cancel** and a **Don't warn again**
   checkbox — at most once per (input source, layout) pair per run, and never
   once permanently suppressed.
5. Snapshot the tuning into a profile-constrained `TypingConfig(profile:…)`
   (which forces the Unicode fallback off on `remoteConsole` and supplies its
   default event pacing unless overridden), then after `leadTime` seconds
   dispatch `engine.type(text, using: layout, config:)` on a background queue.

The **lead time** is the deliberate pause that lets the user click into the
target window (a KVM/console field) before typing begins.

## Settings and Preferences

`Settings` is a `@MainActor enum` over `UserDefaults.standard`. Each property
reads and writes a single key on access, so values stay in sync with disk and
survive relaunches; defaults are returned for keys that were never written.

| Key | Default | Meaning |
|-----|---------|---------|
| `tipsy.targetProfile` | `localMac` | Where keystrokes are interpreted (`TargetProfile` raw value: `localMac` / `remoteConsole`) |
| `tipsy.layoutID` | `de` (`Layouts.defaultLayoutID`) | Active keyboard layout |
| `tipsy.characterDelay` | `0.012` | Seconds between characters |
| `tipsy.jitter` | `0` | Random ± variation on each delay |
| `tipsy.interEventDelay` | unset (nil) | Override for the pause *inside* one stroke (0–0.05s); unset uses the profile default |
| `tipsy.normalizationEnabled` | `true` | Rewrite typographic characters per the profile's preset before typing |
| `tipsy.mismatchWarningSuppressed` | `false` | Permanently silence the input-source / layout mismatch warning |
| `tipsy.unicodeFallback` | `true` | Type unmapped chars as Unicode (forced off for `remoteConsole`) |
| `tipsy.leadTime` | `3` | Countdown before typing starts |
| `tipsy.hotkeyEnabled` | `true` | Global hotkey active |
| `tipsy.hotkeyKeyCode` | `9` (V) | Trigger hotkey virtual key code |
| `tipsy.hotkeyModifiers` | ⌘⇧ | Trigger hotkey modifier flags (raw value) |
| `tipsy.cueSoundEnabled` | `true` | Play the cue sound before typing |
| `tipsy.cueVolume` | `0.7` | Cue volume (0–1) |
| `tipsy.cueVariant` | `rising` | Cue motif (`rising` / `blip` / `chime`) |

"Start at login" is **not** stored here — `LoginItem` uses `SMAppService`, whose
registration state is the source of truth.

`PreferencesWindowController` is a code-built (no nib) window with a **Target**
popup (`localMac` / `remoteConsole`) and a layout popup filtered to that target's
layout kind; sliders for character delay (0–0.2s), jitter (0–0.1s), lead time
(0–10s), event delay (0–50 ms, gated behind an "Override event pacing" checkbox),
and cue volume (0–1); a cue-motif popup with a **Test sound** button; the hotkey
recorder button; and checkboxes for normalization, Unicode fallback (disabled
with an explanatory tooltip on `remoteConsole`), cue sound, global hotkey, and
start-at-login. Each control writes straight through to `Settings` (or the
relevant system service) and calls `onChange`, which makes `AppDelegate` re-apply
settings, refresh the hotkey state, and rebuild the menu live. Selecting a target
or layout in the menu conversely calls `reloadFromSettings()` on an open window.

## Global hotkey

`HotkeyManager` registers a **configurable** combo (default **Cmd+Shift+V**,
set via the Preferences recorder and persisted in `Settings`) using `NSEvent`
monitors rather than a Carbon hot-key, so no extra entitlement is needed:

- A **global** monitor delivers the event while Tipsy is in the background.
- A **local** monitor covers the case where Tipsy itself is the key app (and
  returns the event so it is not swallowed for Tipsy's own UI).

Global monitors require the Accessibility permission, which the app already
holds for keystroke synthesis. Note the global monitor observes but does not
*consume* the event — other apps still receive the combo (see
[permissions-troubleshooting.md](permissions-troubleshooting.md)).

## Cue sound, login item, and icon

- **`PasteCueSound`** synthesizes the cue at runtime with `AVAudioEngine` — no
  bundled audio file. `CueVariant` (`rising` / `blip` / `chime`) defines a short
  note motif; `play()` reads the variant and volume from `Settings`, builds a
  PCM buffer, and schedules it. `play(variant:volume:)` is used for live
  previews from Preferences.
- **`LoginItem`** wraps `SMAppService.mainApp` (macOS 13+) to register /
  unregister start-at-login. It only affects the installed `.app`; running
  unbundled (`swift run`) has no bundle to register and surfaces an error.
- **`TipsyIcon`** draws the menu bar glyph (a clipboard with a caret) in code as
  a template image. The distributable app icon is generated separately by
  `Scripts/make-icons.swift` into `Resources/AppIcon.icns`.

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
