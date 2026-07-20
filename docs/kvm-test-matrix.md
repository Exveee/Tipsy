# KVM verification matrix

This document guides QA testing of Tipsy across different target environments and
keyboard layouts. A **canary string** below acts as a comprehensive test payload
covering all known problematic character classes. The matrix tracks results across
platform and layout combinations; the echo-page helper lets you verify what a
browser-based KVM sees without requiring a real KVM. Use the symptom table to
diagnose anomalies.

## Canary string

Use this string to verify character handling across all layout and target
combinations. It covers the full set of characters that have caused issues in
the past, plus classic symbols and control cases.

```
0123456789
abcdefghijklmnopqrstuvwxyz
ABCDEFGHIJKLMNOPQRSTUVWXYZ
ä ö ü Ä Ö Ü ß
@ € { } [ ] | \ ~ ^ ° § " ' < > - _ + * # ; :
```

This canary string is incomplete; the full test also includes typographic
characters that **must be normalized away before typing**:

- Smart quotes (`„` U+201E, `"` U+201C, `'` U+2018, `'` U+2019) → regular ASCII
  equivalents (`"` U+0022, `'` U+0027)
- En dash (`–` U+2013) → hyphen (`-` U+002D)
- Non-breaking space (NBSP, U+00A0) → regular space (U+0020)
- CRLF line-break sample (Windows line ending) → LF (Unix standard)

### What each group verifies

- **Digits (0–9):** baseline keystroke synthesis without modifiers
- **Lowercase alphabet (a–z):** unshifted ASCII characters
- **Uppercase alphabet (A–Z):** shift pairing and modifier registration
- **German umlauts (ä ö ü Ä Ö Ü ß):** dead-key sequences and AltGr layouts on
  target; detects when the wrong macOS input source is active or when a PC
  layout is not selected on the remote
- **Special characters (@, €, {}, [], |, \, ~, ^, °, §):** AltGr and
  combination-key positions; critical for KVM consoles accepting special chars
  in passwords and commands
- **Quotes and angle brackets (" ', <, >):** directional variants and shift
  pairing; often mistyped when modifier flags are dropped or scrambled
- **Dashes, punctuation, and math (-, _, +, *, #, ;, :):** keyboard row
  positions; sensitive to inter-character delay when targets buffer slowly
- **Typographic normalization (smart quotes, en dash, NBSP, CRLF):** verifies
  Unicode preprocessing before keystroke synthesis; these must never appear as
  keystrokes

## Test matrix

Track results by filling cells with `✓` (pass), `✗` (fail), or `–` (not tested).
For each result, add the tester's initials and the date (e.g., `✓ PD 2025-02-14`).

| Target | Local Mac<br/>German | Local Mac<br/>US/Dynamic | Remote/KVM<br/>German PC | Remote/KVM<br/>US PC |
|--------|:---:|:---:|:---:|:---:|
| **TextEdit (local)** | – | ✓ PD 2026-07-20 ³ | n/a | n/a |
| **Browser key-event echo** | – | – | n/a | n/a |
| **Guacamole/Teleport web KVM** | – | – | – | – |
| **PiKVM or IPMI console** | – | – | ✓ PD 2026-07-20 | – |
| **VNC client (TigerVNC, RealVNC)** | – | – | ✓ PD 2026-07-20 ¹ | – ² |

¹ Proxmox noVNC web console, Debian 13 host with PC-German layout — full
canary correct.

² Not yet testable: the only available remote host uses a German layout, so
the US (PC/Remote) column has no valid target. A cross-check against that
German host on 2026-07-20 confirmed the *expected* mismatch behavior — Y/Z
transposed, symbols remapped per the German layout — and the skipped-character
report correctly listed the 10 characters absent from the US layout
(`äöüÄÖÜß€°§`) instead of typing garbage. Needs a US-layout host
(`loadkeys us`) for a real ✓.

³ Dynamic layout with a German macOS input source. Retest after the
main-thread fix for the TIS crash (#38) — full canary correct.

### Legend

- **✓** — All canary characters typed correctly; no stray, dropped, or garbled
  characters.
- **✗** — One or more canary characters failed; see the symptom table below.
- **–** — Not yet tested; use this as a baseline.
- **n/a** — Not applicable (e.g., remote layouts on local TextEdit).
- **Tester info** — Append initials and date (ISO 8601: YYYY-MM-DD) to each result.

## Echo-page helper

Use this HTML page to inspect what a browser-based KVM will see during
keystroke events. Open it in the same browser and target OS you will test
with — it logs the `event.key`, `event.code`, and modifier state (`shift`,
`option`/`alt`, `control`, `meta`/`cmd`) for every keydown event into a
`<pre>` element.

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Keystroke Echo</title>
    <style>
        * { box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            padding: 20px;
            background: #f5f5f5;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
            background: white;
            border-radius: 8px;
            padding: 20px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        h1 { font-size: 1.25rem; margin-top: 0; }
        #log {
            background: #222;
            color: #0f0;
            padding: 12px;
            border-radius: 4px;
            font-family: "Courier New", monospace;
            font-size: 12px;
            line-height: 1.5;
            height: 300px;
            overflow-y: auto;
            white-space: pre-wrap;
            word-break: break-all;
        }
        .info {
            background: #e8f4f8;
            border-left: 4px solid #0080c0;
            padding: 12px;
            margin: 16px 0;
            font-size: 0.9rem;
            border-radius: 4px;
        }
        button {
            background: #0080c0;
            color: white;
            border: none;
            padding: 8px 16px;
            border-radius: 4px;
            cursor: pointer;
            margin-top: 12px;
        }
        button:hover { background: #0066a0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Keystroke Echo Viewer</h1>
        <div class="info">
            <strong>Focus on this page</strong> and type or paste from Tipsy.
            Every keydown event is logged below with <code>event.key</code>,
            <code>event.code</code>, and modifier flags.
        </div>
        <pre id="log">Waiting for input...</pre>
        <button onclick="document.getElementById('log').textContent = ''">Clear log</button>
    </div>

    <script>
        const log = document.getElementById('log');
        let lineCount = 0;
        const maxLines = 100;

        document.addEventListener('keydown', (e) => {
            const mods = [
                e.shiftKey ? 'shift' : '',
                e.altKey ? 'alt' : '',
                e.ctrlKey ? 'ctrl' : '',
                e.metaKey ? 'meta' : ''
            ].filter(Boolean).join('+') || 'none';

            const line = `${e.code.padEnd(15)} key="${e.key.padEnd(6)}" mods=${mods}\n`;

            log.textContent += line;
            lineCount++;

            if (lineCount > maxLines) {
                const lines = log.textContent.split('\n');
                log.textContent = lines.slice(-maxLines).join('\n');
            }

            // Keep scroll at bottom
            log.scrollTop = log.scrollHeight;
        });
    </script>
</body>
</html>
```

To use it:

1. Save the code above as an `.html` file on your machine (or host it on a web server).
2. Open it in a browser running on the **target OS** (the OS where Tipsy will send
   keystrokes — e.g., a Linux guest, a Windows VM, or a remote console).
3. Copy the canary string (or a test string) on your Mac.
4. Set Tipsy's layout to match the target's keyboard layout.
5. Press **⌘⇧V** (or click **Type Clipboard**) with the lead time set to 3+ seconds.
6. Immediately click into the echo page's text area and wait.
7. After Tipsy types, review the log: `event.key` should match the characters you
   copied, and `event.code` should reflect the physical key pressed for that layout.
   Modifier flags should be clear and consistent — stray modifiers indicate a
   keystroke synthesis bug or remote input-interpretation lag.

## Known symptom → cause table

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Stray `a` characters appear (e.g., `ä` becomes `aa`) | Unicode fallback triggered for unmapped character on a virtual key with code 0; a fallback loop bug | Upgrade to latest version; if persists, file a bug with the target layout and character. |
| `2` typed instead of `"` (or other shifted char is unshifted) | Modifier flag not registered before the keystroke; remote saw the key without shift | Increase inter-character delay in Preferences (try 0.05s) or check if the remote console is dropping fast modifier changes. |
| `œ` or wrong bracket on a PC remote (e.g., `{` becomes `Ü`) | macOS German (QWERTY) layout selected for a PC remote (QWERTZ); AltGr position mismatch | In Tipsy's menu, select **German (QWERTZ)** if targeting a German PC, or **US (QWERTY)** for a US PC; check the target OS's keyboard layout setting. |
| All text garbled or mojibake | macOS input source mismatch (e.g., ß tries to type on a non-German source) | Switch macOS input source to **German** if typing German text, or ensure Tipsy's layout matches your Mac's active input source. |
| Every character types but lag increases mid-string | Target console buffering slowly; dropped inter-event delays | Increase character delay or jitter in Preferences; reduce clipboard payload size for testing. |
| Umlauts type but as separate chars (ä → a¨) | Target app is decomposing composed Unicode; dead-key fallback active | Verify the target app accepts composed forms (NFD vs. NFC); if it enforces decomposition, Tipsy will type the base + combining mark as separate events. |
