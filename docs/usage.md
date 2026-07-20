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

The **Target** section above the layout list chooses *where* those keystrokes
land — an app on this Mac (**Local Mac**, the default) or a machine behind a
KVM/console (**Remote console (KVM)**). The target filters the layout list: Local
Mac offers the macOS layouts (plus a **Dynamic (Local)** entry that follows your
current input source), while Remote console offers the PC/scancode layouts. See
[Typing into a KVM console](#typing-into-a-kvm-console) for the remote workflow.

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

- **Target** (default *Local Mac*) — where the keystrokes are interpreted:
  *Local Mac* (an app on this Mac) or *Remote console (KVM)* (a machine reached
  through a KVM/VNC/IPMI/web console). The choice filters the layout list to the
  layouts that make sense for it and constrains the options below. See
  [Typing into a KVM console](#typing-into-a-kvm-console).
- **Default layout** — the layout used for typing, filtered by the target.
- **Character delay** (0–0.2s, default 0.012s) — pause between each character.
  Slow console targets can drop input that arrives too fast; raise this if
  characters go missing.
- **Jitter** (0–0.1s, default 0) — random ± variation added to each delay to
  make typing look less mechanical.
- **Lead time** (0–10s, default 3s) — the focus countdown described above.
- **Override event pacing** + **Event delay** (0–50 ms) — the pause between the
  individual events *inside* one keystroke (a modifier press and the key press).
  Left unchecked, Tipsy uses the target's default (0 ms local, 8 ms remote).
  Check it and raise the slider if a remote console drops modifiers so that e.g.
  `"` arrives as `2`.
- **Normalize typographic characters** (default on) — rewrites smart quotes,
  dashes, non-breaking spaces, the ellipsis, invisible characters, and CRLF line
  endings from pasted text into their typeable equivalents. On a remote console
  every typographic character is rewritten (it can't be typed there otherwise);
  on Local Mac only invisibles and line endings are touched.
- **Type unmapped characters as Unicode** (default on) — when a character has
  no mapping in the chosen layout, type it directly via its Unicode value
  instead of skipping it. **Disabled for the Remote console target**: KVM
  clients see the fallback's key code 0 as the `A` key, so unmapped characters
  would arrive as a stray `a`.
- **Trigger hotkey** — click the recorder button and press a new combo to
  rebind the global trigger (default ⌘⇧V).
- **Play cue sound before typing** (default on) — a short distinctive tone when
  typing is triggered.
- **Cue sound** — pick the motif (Rising / Blip / Chime); selecting one previews it.
- **Cue volume** (0–100%, default 70%) — loudness of the cue. **Test sound**
  plays it at the current settings.
- **Enable global hotkey** (default on) — toggles the global trigger.
- **Start Tipsy at login** (default off) — registers Tipsy as a login item via
  `SMAppService` so it launches automatically. Only effective for the installed
  app in `/Applications`.

## Typing into a KVM console

A KVM-over-IP / BMC / hypervisor console (iDRAC, iLO, IPMI, PiKVM, Guacamole,
Teleport, Proxmox noVNC, VNC clients, …) doesn't route your keystrokes through
macOS. It forwards the physical **key position** and real modifier state, and the
*remote* host interprets them with *its own* PC layout. Two things follow: you
must pick a layout matching the remote host, and typographic characters and the
Unicode fallback can't be used there.

1. **Set the target to *Remote console (KVM)*.** Menu **⌨︎ → Target → Remote
   console (KVM)**, or the **Target** popup in Preferences. This switches the
   layout list to the PC/scancode layouts, turns on remote event pacing (an 8 ms
   gap inside each keystroke so a KVM doesn't miss the modifier), and disables
   the Unicode fallback.
2. **Pick the PC layout that matches the *remote host's* keyboard layout** — not
   your Mac's. Choose **German (PC/Remote)** if the remote OS is set to German
   (QWERTZ), **US (PC/Remote)** if it's set to US (QWERTY). If the remote layout
   and the layout you pick disagree, AltGr symbols and brackets come out wrong.
3. **Leave *Normalize typographic characters* on** (the default). A remote
   console can't type smart quotes, en/em dashes, non-breaking spaces, the `…`
   ellipsis, or invisible characters at all, so Tipsy rewrites text pasted from
   Word/Slack/browsers into the ASCII equivalents (`"`, `'`, `-`, ` `, `...`)
   and normalizes CRLF to LF before typing.
4. **Copy** the text on your Mac (a password, a config snippet, a command).
5. **Trigger** with **⌘⇧V** (or the menu), then **immediately click into the
   console field** so it has focus before the lead-time countdown ends.
6. Tipsy types the text after the lead time, at the configured speed. Characters
   the PC layout can't produce are reported as skipped (there is no Unicode
   fallback on a remote target).

If a remote console drops fast modifier changes (a shifted character arrives
unshifted), raise **Event delay** under **Override event pacing**, or increase
the character delay.

### Verifying and troubleshooting

Use the canary string and the browser key-event echo page in
[kvm-test-matrix.md](kvm-test-matrix.md) to confirm what the remote actually
receives. Common symptoms:

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Stray `a` appears (e.g. `ä` → `aa`) | The Unicode fallback fired on a remote target (key code 0 = `A`) | Keep the target set to **Remote console (KVM)**, which disables the fallback; leave normalization on so typographic characters don't reach it. |
| `2` typed instead of `"` (a shifted char arrives unshifted) | The KVM registered the key before the modifier | Check **Override event pacing** and raise **Event delay** (try 20–50 ms); a higher character delay also helps. |
| `œ` or the wrong bracket (e.g. `{` → `Ü`) | The chosen PC layout doesn't match the remote host's layout | Select **German (PC/Remote)** for a German remote or **US (PC/Remote)** for a US remote, and check the remote OS's own keyboard-layout setting. |
| Text fully garbled / mojibake | Wrong target or layout family — an Apple-local layout typed into a remote console | Switch the **Target** to *Remote console (KVM)* and pick a PC layout; Apple-local layouts assume macOS composes the keys. |

See the full [symptom → cause table](kvm-test-matrix.md#known-symptom--cause-table)
for more.
