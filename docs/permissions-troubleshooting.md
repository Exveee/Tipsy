# Permissions & troubleshooting

Most "Tipsy isn't typing" problems come down to the Accessibility permission,
the global hotkey, or a character the active layout can't map. This page covers
each.

## The Accessibility permission

Tipsy synthesizes keystrokes by posting Quartz `CGEvent`s to the system event
tap. macOS only delivers those events from a process that holds the
**Accessibility** permission. `AccessibilityManager` checks it via
`AXIsProcessTrusted()`:

- `AccessibilityManager.isTrusted` — current trust status.
- `AccessibilityManager.ensureTrusted(prompt: true)` — checks, and shows the
  system dialog directing you to System Settings if untrusted (called once at
  launch).

Grant it under **System Settings → Privacy & Security → Accessibility** →
enable **Tipsy**. If Tipsy isn't listed, click **+** and add the app bundle
(`dist/Tipsy.app`).

### Why nothing types when it's missing

Without the permission the keystroke events are **silently dropped** — there is
no error from the OS. The symptom is simply that nothing appears in the target
window. Tipsy guards against this in `typeClipboard()`: if it isn't trusted it
shows *"Grant Accessibility permission in System Settings"* instead of trying to
type. If you see that alert, the permission is the problem.

### Re-adding the app after a rebuild

macOS's permission database (TCC) keys the Accessibility grant to the app's
**code-signing designated requirement**, not just its path. With an *ad-hoc*
signature (`codesign --sign -`, the fallback default) the identity changes every
build, so after rebuilding the `.app` macOS treats it as a different program and
the existing grant won't apply.

**Fix — stable signature (recommended):** run once

```bash
./Scripts/make-signing-cert.sh   # self-signed "Tipsy Local Signing" cert
./Scripts/bundle.sh release      # auto-detects and signs with it
```

`bundle.sh` then signs every build with that identity, so the designated
requirement (`identifier "com.exveee.tipsy" and certificate leaf = …`) stays
constant and the grant **persists across rebuilds**. You grant Accessibility one
more time right after switching (the signature changes from ad-hoc), then it
sticks. Verify the identity exists with
`security find-identity -p codesigning` (it shows as `CSSMERR_TP_NOT_TRUSTED` —
that's fine; self-signed certs are untrusted for *distribution* but fully usable
for signing and for a stable TCC identity).

**If you're still on ad-hoc** and typing stops after a rebuild:

1. Open **System Settings → Privacy & Security → Accessibility**.
2. Remove the old **Tipsy** entry (select it, click **−**).
3. Add the freshly built `dist/Tipsy.app` again (click **+**), and enable it.

A paid **Developer ID Application** signature (pass `SIGN_IDENTITY` to
`bundle.sh`) additionally lets the app run on *other* Macs without Gatekeeper
warnings; it isn't needed for stable permissions on your own machine.

## Hotkey conflicts

The global trigger defaults to **Cmd+Shift+V** and is customizable via the
recorder in **Preferences → Trigger hotkey**. It is implemented with `NSEvent`
global and local monitors in `HotkeyManager` (no Carbon hot-key / extra
entitlement).

Be aware:

- **The global monitor observes events but does not consume them** —
  `NSEvent.addGlobalMonitorForEvents` is observe-only by design. So if the
  configured combo also means something in the focused app (e.g. ⌘⇧V is "paste
  and match style" in many editors), *both* happen: that app acts on the combo
  **and** Tipsy starts its countdown. If that's disruptive, rebind the hotkey to
  a less common combo in Preferences, or disable it (**Preferences → Enable
  global hotkey**) and use the menu item instead.
- The global monitor only fires while another app is focused. When Tipsy itself
  is key, the **local** monitor handles the combo (and forwards the event on).
- The hotkey relies on the same Accessibility permission as typing; if that
  permission is missing, the global monitor won't receive key events either.

## Characters that don't type

If most text types but specific characters are missing or wrong:

- **Layout gaps.** Each layout maps only the characters it defines. A character
  with no mapping returns `nil` from `keyStroke(for:)`. The German and UK
  layouts are still expanding, so some symbols may be unmapped.
- **Dead keys are not supported.** Tipsy posts one key-down/key-up pair per
  character and cannot perform multi-stroke dead-key sequences. For example
  Apple German `~` (Option+N then Space) and accent dead keys (`^`, `´`,
  `` ` ``) are intentionally left unmapped. UK `¬` / `|` on the grave key are
  also unverified and unmapped.
- **Unicode fallback.** When **Type unmapped characters as Unicode** is on
  (default), unmapped characters are typed directly via their Unicode scalar
  values (`keyboardSetUnicodeString`) instead of being skipped. This usually
  fills the gaps, but some targets — especially raw console / BMC text fields —
  ignore Unicode-injected events, so the character may still not appear there.
- **Turn fallback off to see the gaps.** With Unicode fallback disabled,
  `KeystrokeEngine.type(_:using:)` returns the list of characters it couldn't
  type, so you can tell exactly which ones the layout is missing.

If a character is wrong rather than missing, the active layout's mapping for it
may be incorrect for the target keyboard — try matching Tipsy's layout to the
target machine's layout (see [usage.md](usage.md#pick-a-layout)).
