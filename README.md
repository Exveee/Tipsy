# Tipsy

**Type your clipboard.** A macOS menu bar app that types the contents of your
clipboard as real keystrokes — for systems where pasting is blocked: KVM/BMC
consoles (iDRAC, iLO, IPMI, PiKVM), hypervisor web consoles (Proxmox noVNC,
VMware, Hyper-V), and hardened or air-gapped VMs.

It reads the clipboard and posts genuine key-down/key-up events, mapped through
a selectable **keyboard layout** — so what you copy is what the target machine
receives, even when its layout differs from yours.

> Status: **v0.1.0**, in active development. Fully usable; layout coverage is
> still expanding (see [Roadmap](#roadmap)).

---

## Install

You only need a Mac with **macOS 13+** and Apple's **Command Line Tools** (no
Xcode). If `swift --version` doesn't work, install them once:

```bash
xcode-select --install
```

Then:

```bash
git clone https://github.com/Exveee/Tipsy.git
cd Tipsy

# 1) One-time: create a local signing cert so the Accessibility
#    permission sticks across updates (no re-granting later).
./Scripts/make-signing-cert.sh

# 2) Build and install into /Applications (also appears in Launchpad).
./Scripts/install.sh release

# 3) Launch it.
open /Applications/Tipsy.app
```

> On the very first `install.sh` run a keychain prompt ("codesign wants to use
> the signing key") may appear — choose **Always Allow**.

### Grant the Accessibility permission

Tipsy synthesizes keystrokes, which macOS gates behind the Accessibility
permission. On first launch it opens the prompt; otherwise:

1. **System Settings → Privacy & Security → Accessibility**
2. Add / enable **Tipsy**.

Nothing will type until this is granted. Thanks to the signing cert from step 1,
you only do this **once** — it survives rebuilds and updates.

---

## Using it

Tipsy lives in the **menu bar** (clipboard glyph, no Dock icon).

1. Copy the text you need (password, command, config snippet).
2. Click the menu bar icon → pick the **layout that matches the target machine**.
3. Choose **Type Clipboard**, or press the global hotkey **⌘⇧V**.
4. A short cue sound plays and a **lead-time countdown** starts — click into the
   target field before it ends.
5. Tipsy types the text at the configured speed.

### Preferences (⌘,)

All settings apply live and persist:

| Setting | Default | What it does |
|---|---|---|
| Default layout | German | Layout used for typing |
| Character delay | 0.012 s | Pause between characters — raise it if a slow console drops input |
| Jitter | 0 s | Random ± variation per character |
| Lead time | 3 s | Countdown before typing, to focus the target window |
| Type unmapped as Unicode | on | Type characters the layout can't map via their Unicode value |
| Cue sound | Rising | Motif played before typing (Rising / Blip / Chime), with volume + **Test** |
| Trigger hotkey | ⌘⇧V | Rebind via the recorder button |
| Enable global hotkey | on | Toggle the global trigger |
| Start Tipsy at login | off | Launch automatically when you log in |

> The default ⌘⇧V also means "paste and match style" in some apps. If that
> clashes, rebind the hotkey in Preferences.

### Shipped layouts

| ID | Layout | Coverage |
|---|---|---|
| `de` | German (QWERTZ) | Letters, umlauts, ß, digits, AltGr (`@ € { } [ ] \| \`), dead keys (`^ ´ \` ~`) |
| `us` | US (QWERTY) | Full printable ASCII |
| `uk` | UK (QWERTY) | US base + British overrides (`£`, `@`/`"`, `#`/`~`, `€`) — partly hardware-verified |
| `ch-de` | Swiss German (QWERTZ) | Letters, à/é/è + umlauts (shift), digits — Option layer not yet hardware-verified |

---

## Update / uninstall

Update — pull and reinstall (permission stays granted):

```bash
git pull
./Scripts/install.sh release
```

Uninstall:

```bash
./Scripts/uninstall.sh           # quit + remove /Applications/Tipsy.app
./Scripts/uninstall.sh --purge   # also remove preferences + the signing cert
```

Then remove the **Tipsy** entry under System Settings → Privacy & Security →
Accessibility (macOS doesn't allow scripting that).

---

## For developers

### Build & test (local, no Xcode, no CI)

```bash
./Scripts/check.sh       # local CI: swift build + run the test suite
swift build              # compile only
swift run Tipsy          # run without bundling (no Dock icon)
swift run TipsyCheck     # run the test suite on its own
./Scripts/bundle.sh release   # assemble dist/Tipsy.app (no install)
```

Tests run as a plain executable (`TipsyCheck`), not XCTest — both XCTest and
swift-testing are unavailable with Command Line Tools alone, so this keeps tests
runnable locally. There is no GitHub Actions; everything runs on your machine.

### How it works

```
┌────────────┐   text    ┌──────────────┐   KeyStroke   ┌────────────────┐  CGEvent
│ Clipboard  │ ────────▶ │ KeyboardLayout│ ───────────▶ │ KeystrokeEngine│ ────────▶ focused app
│ (NSPasteb.)│           │  (char → key) │              │  (Quartz post) │
└────────────┘           └──────────────┘              └────────────────┘
```

1. **ClipboardReader** reads plain text from `NSPasteboard`.
2. **KeyboardLayout** maps each `Character` to a `KeyStroke` (virtual key code +
   Shift/Option), or a sequence for dead keys.
3. **KeystrokeEngine** posts each stroke as a Quartz `CGEvent`
   (`.cghidEventTap`), with delay + optional jitter. Unmapped characters fall
   back to direct Unicode posting when enabled.
4. **AppDelegate** is the menu bar UI; **Settings** persists everything via
   `UserDefaults`; **HotkeyManager** registers the global trigger.

### Project layout

```
Tipsy/
├── Package.swift                 # SwiftPM: TipsyKit lib + Tipsy app + TipsyCheck runner
├── Sources/
│   ├── TipsyKit/                 # Reusable library (Core / Layouts / Permissions)
│   └── Tipsy/                    # Menu bar app (main.swift + App/)
├── Tests/TipsyCheck/             # Plain executable test runner
├── Resources/                    # Info.plist, AppIcon.icns
└── Scripts/
    ├── install.sh / uninstall.sh # Install to / remove from /Applications
    ├── bundle.sh                 # Build → assemble Tipsy.app
    ├── make-signing-cert.sh      # Self-signed cert for stable permissions
    ├── make-icons.swift          # Render the app icon .iconset
    ├── check.sh                  # Local build + test
    └── release.sh                # Signed/notarized build (Developer ID env vars)
```

### Code signing

`bundle.sh` picks the identity automatically:

- **Local self-signed** (`Tipsy Local Signing`, from `make-signing-cert.sh`) —
  stable designated requirement, so the Accessibility grant persists. Recommended
  for everyday use. Not a trusted/distributable signature.
- **Developer ID** — pass `SIGN_IDENTITY="Developer ID Application: … (TEAMID)"`
  for a signature other Macs accept; `release.sh` adds notarization when the
  `AC_API_*` env vars are set. Requires a paid Apple Developer account.
- **Ad-hoc** (fallback when no identity is found) — changes every build, so the
  permission must be re-granted after each rebuild.

> **Security note:** the local self-signed / ad-hoc identity is for local use
> only. Distributing to other machines should use Developer ID + notarization so
> the login item and Accessibility grant bind to a strong Team-ID identity,
> mitigating bundle-replacement persistence (see issue #23).

### More docs

- [Usage guide](docs/usage.md)
- [Architecture](docs/architecture.md)
- [Adding a layout](docs/adding-a-layout.md)
- [Permissions & troubleshooting](docs/permissions-troubleshooting.md)

---

## Roadmap

- [ ] Verify the UK and Swiss German Option layers on real hardware.
- [ ] Dead-key accents producing precomposed letters (é è ñ …), not just the
      standalone accent symbols.
- [ ] Add more keyboard layouts.
- [ ] Optional Developer ID signing + notarization for distribution beyond this team.

## License

TBD.
