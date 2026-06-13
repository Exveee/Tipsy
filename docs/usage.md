# Usage guide

Tipsy types the contents of your clipboard as real keystrokes into whatever
window is focused — for places where pasting is blocked (KVM consoles, remote
IPMI/iDRAC/iLO sessions, hypervisor web consoles, locked-down VMs).

## Install / build

Tipsy ships as a Swift Package — there is no Xcode project. You need macOS 13+
and the Swift 6 toolchain (Command Line Tools is enough to build).

```bash
# Build the executable
swift build

# Assemble a runnable Tipsy.app (ad-hoc signed) into ./dist
./Scripts/bundle.sh release
open dist/Tipsy.app
```

Tipsy launches as a menu bar accessory: no Dock icon and no main window — look
for the **⌨︎** icon in the menu bar.

## Grant the Accessibility permission

Synthesizing keystrokes requires the macOS **Accessibility** permission.
On first launch Tipsy prompts you; grant it under:

**System Settings → Privacy & Security → Accessibility** → enable **Tipsy**.

If Tipsy is not yet listed, click **+** and add `dist/Tipsy.app`. Without this
permission, posted keystrokes are silently dropped and nothing types. See
[permissions-troubleshooting.md](permissions-troubleshooting.md) if typing does
nothing.

## Pick a layout

Click the **⌨︎** menu bar icon and choose your layout under **Layout**
(a checkmark marks the active one):

- **German (QWERTZ)** — default
- **US (QWERTY)**
- **UK (QWERTY)**

The layout is the layout of the **target** machine — it decides which physical
keys Tipsy presses so the remote end receives the characters you copied, even
if its keyboard layout differs from yours. Your choice is remembered across
launches.

## Type the clipboard

1. Copy the text you want to send.
2. Click **⌨︎ → Type Clipboard** (the menu shows the current lead time, e.g.
   *Type Clipboard (3s)*), or press the global hotkey (below).
3. **Immediately click into the target window/field** — the console, VM
   console, or BMC text box you want to type into.
4. After the **lead time** countdown, Tipsy types the clipboard there.

### The lead-time focus delay

The lead time is a deliberate pause (default 3s, configurable 0–10s) between
triggering and the first keystroke. It exists so you can move focus to the
target window before typing starts — otherwise the keystrokes would land in
Tipsy's own menu or the wrong app. Set it long enough to comfortably click into
the destination.

### The global hotkey: Cmd+Shift+V (customizable)

With the hotkey enabled (default), **⌘⇧V** triggers typing from anywhere
without opening the menu — handy when your hands are already on the keyboard in
a console window. The same lead-time countdown applies, so press it, then focus
the target. Rebind it with the recorder in **Preferences → Trigger hotkey**, or
disable it entirely. Note the default combo is "paste and match style" in many
editors — see
[permissions-troubleshooting.md](permissions-troubleshooting.md#hotkey-conflicts).

## Preferences

Open **⌨︎ → Preferences…** (or ⌘,). All changes apply live and persist:

- **Default layout** — the layout used for typing.
- **Character delay** (0–0.2s, default 0.012s) — pause between each character.
  Slow console targets can drop input that arrives too fast; raise this if
  characters go missing.
- **Jitter** (0–0.1s, default 0) — random ± variation added to each delay to
  make typing look less mechanical.
- **Lead time** (0–10s, default 3s) — the focus countdown described above.
- **Type unmapped characters as Unicode** (default on) — when a character has
  no mapping in the chosen layout, type it directly via its Unicode value
  instead of skipping it.
- **Trigger hotkey** — click the recorder button and press a new combo to
  rebind the global trigger (default ⌘⇧V).
- **Play cue sound before typing** (default on) — a short distinctive tone when
  typing is triggered.
- **Cue sound** — pick the motif (Rising / Blip / Chime); selecting one previews it.
- **Cue volume** (0–100%, default 70%) — loudness of the cue. **Test sound**
  plays it at the current settings.
- **Enable global hotkey** (default on) — toggles the global trigger.

## Typical KVM / console workflow

1. Open your KVM-over-IP / BMC / hypervisor console (iDRAC, iLO, IPMI, PiKVM,
   Proxmox noVNC, …) and click into the field you need to fill.
2. Set Tipsy's layout to match the **target** machine's keyboard layout.
3. Copy the text (a password, a config snippet, a long command) on your Mac.
4. Press **⌘⇧V** (or use the menu), then click back into the console field.
5. Tipsy types the text after the lead time, at the configured speed. If some
   characters can't be typed by the layout and Unicode fallback is off, Tipsy
   reports which ones were skipped.
