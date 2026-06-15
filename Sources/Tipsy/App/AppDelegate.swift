import AppKit
import TipsyKit

/// Menu bar controller: lets the user pick a layout and trigger typing of the
/// current clipboard into whatever window is focused after a short countdown.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {

    private var statusItem: NSStatusItem!
    private let engine = KeystrokeEngine()
    private let layouts = Layouts.all
    private var activeLayout: KeyboardLayout

    /// Seconds to wait after triggering so the user can focus the target window.
    private var leadTime: TimeInterval = 3

    private let hotkey = HotkeyManager()
    private var preferences: PreferencesWindowController?

    /// Single serial queue for the blocking typing run, so overlapping triggers
    /// can never interleave keystrokes (#12).
    private let typingQueue = DispatchQueue(label: "com.exveee.tipsy.typing")

    /// Main-actor guard: a new trigger is ignored while a run is scheduled or
    /// active (#12). Also drives whether "Stop Typing" is enabled.
    private var isTyping = false

    /// The lead-time wait + typing run; cancellable via "Stop Typing" (#22).
    private var typingTask: Task<Void, Never>?

    /// Above this many characters, confirm before typing so a huge clipboard
    /// can't silently block for minutes (#22).
    private static let maxTypingLength = 20_000

    override init() {
        activeLayout = layouts[0]
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // #25: only check trust status on launch; the system prompt is deferred
        // to the first typing attempt while untrusted.
        _ = AccessibilityManager.isTrusted
        applySettings()
        buildStatusItem()

        hotkey.onTrigger = { [weak self] in self?.typeClipboard() }
        applyHotkeyState()

        // Re-arm the global hotkey once Accessibility is granted: a global
        // monitor installed while untrusted never fires until re-installed.
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(accessibilityTrustChanged),
            name: NSNotification.Name("com.apple.accessibility.api"),
            object: nil
        )

        // The global hotkey is dead without Accessibility, and the deferred
        // prompt (#25) only fires from a menu-driven type. A user who only
        // presses the hotkey would get no feedback at all, so prompt at launch
        // when the hotkey is on but we are not yet trusted.
        if Settings.hotkeyEnabled, !AccessibilityManager.isTrusted {
            AccessibilityManager.ensureTrusted(prompt: true)
        }
    }

    /// Fired (off the main thread) when the Accessibility trust list changes.
    /// Re-arms the hotkey monitors so the global combo starts working without
    /// requiring an app relaunch.
    @objc private func accessibilityTrustChanged() {
        Task { @MainActor [weak self] in
            guard let self, AccessibilityManager.isTrusted else { return }
            self.hotkey.reload()
        }
    }

    /// Loads persisted settings into the lead time and active layout. The
    /// engine's timing/fallback inputs are snapshotted per-run into a
    /// ``TypingConfig`` (see ``typeClipboard``), not stored on the engine.
    private func applySettings() {
        leadTime = Settings.leadTime
        activeLayout = layouts.first { $0.id == Settings.layoutID } ?? layouts[0]
    }

    private func applyHotkeyState() {
        // Push the persisted binding into the manager so the live match
        // reflects whatever the user configured in Preferences.
        hotkey.configure(
            keyCode: UInt16(Settings.hotkeyKeyCode),
            modifiers: NSEvent.ModifierFlags(rawValue: Settings.hotkeyModifiers)
        )
        if Settings.hotkeyEnabled {
            hotkey.enable()
        } else {
            hotkey.disable()
        }
    }

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = TipsyIcon.statusItemImage()
        statusItem.button?.toolTip = "Tipsy — type clipboard"
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let type = NSMenuItem(title: "Type Clipboard (\(Int(leadTime))s)",
                              action: #selector(typeClipboard), keyEquivalent: "")
        type.target = self
        // Mirror the configured global hotkey as the menu accelerator (only when
        // it maps to a plain character; otherwise show no shortcut).
        if Settings.hotkeyEnabled,
           let ke = HotkeyFormat.menuKeyEquivalent(for: UInt16(Settings.hotkeyKeyCode)) {
            type.keyEquivalent = ke
            type.keyEquivalentModifierMask =
                NSEvent.ModifierFlags(rawValue: Settings.hotkeyModifiers)
                    .intersection(HotkeyFormat.relevantModifiers)
        }
        menu.addItem(type)

        // #22: cancel an in-progress run. Enabled only while typing (see
        // validateMenuItem). Esc as the accelerator when the menu is open.
        let stop = NSMenuItem(title: "Stop Typing",
                              action: #selector(stopTyping), keyEquivalent: "\u{1b}")
        stop.keyEquivalentModifierMask = []
        stop.target = self
        menu.addItem(stop)

        menu.addItem(.separator())

        let header = NSMenuItem(title: "Layout", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        for layout in layouts {
            let item = NSMenuItem(title: layout.displayName,
                                  action: #selector(selectLayout(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = layout.id
            item.state = layout.id == activeLayout.id ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let prefs = NSMenuItem(title: "Preferences…",
                               action: #selector(openPreferences), keyEquivalent: ",")
        prefs.target = self
        menu.addItem(prefs)

        let quit = NSMenuItem(title: "Quit Tipsy", action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
    }

    @objc private func selectLayout(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let layout = layouts.first(where: { $0.id == id }) else { return }
        activeLayout = layout
        Settings.layoutID = id
        rebuildMenu()
    }

    @objc private func openPreferences() {
        if preferences == nil {
            let controller = PreferencesWindowController()
            controller.onChange = { [weak self] in self?.preferencesDidChange() }
            preferences = controller
        }
        preferences?.present()
    }

    /// Re-applies persisted settings after the user edits them in Preferences.
    private func preferencesDidChange() {
        applySettings()
        applyHotkeyState()
        rebuildMenu()
    }

    @objc private func typeClipboard() {
        // #12: ignore re-triggers while a run is scheduled or active.
        guard !isTyping else { return }

        // #25: prompt for Accessibility only now, on the first attempt to type
        // while untrusted — not on every cold launch.
        guard AccessibilityManager.isTrusted else {
            AccessibilityManager.ensureTrusted(prompt: true)
            notify("Grant Accessibility permission in System Settings, then try again.")
            return
        }

        // #15: hold the secret only as a local; never store it on `self`, and
        // drop the reference as soon as the run finishes.
        guard let text = ClipboardReader.text(), !text.isEmpty else {
            notify("Clipboard is empty")
            return
        }

        // #22: confirm before typing a huge clipboard that would block for ages.
        if text.count > Self.maxTypingLength {
            let alert = NSAlert()
            alert.messageText = "Tipsy"
            alert.informativeText =
                "The clipboard holds \(text.count) characters. Typing it may take a long time. Continue?"
            alert.addButton(withTitle: "Type Anyway")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }

        // #12: snapshot tuning into an immutable, Sendable config at trigger
        // time so the background run never races the main actor.
        let config = TypingConfig(
            characterDelay: Settings.characterDelay,
            jitter: Settings.jitter,
            unicodeFallback: Settings.unicodeFallback
        )
        let layout = activeLayout
        let engine = self.engine
        let queue = typingQueue
        let cueEnabled = Settings.cueSoundEnabled
        let lead = leadTime

        // #10: remember the app we intend to type into, to re-check after the
        // countdown.
        let targetPID = NSWorkspace.shared.frontmostApplication?.processIdentifier

        isTyping = true
        engine.resetCancellation()

        typingTask = Task { @MainActor [weak self] in
            // #22: cancellable lead-time wait so the user can focus the target.
            try? await Task.sleep(nanoseconds: UInt64(max(0, lead) * 1_000_000_000))
            guard let self, self.isTyping, !Task.isCancelled else {
                self?.finishTyping()
                return
            }

            // #10: abort if focus moved to a different app during the countdown,
            // so the secret is never typed into the wrong window.
            let nowPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
            guard nowPID == targetPID else {
                self.finishTyping()
                self.notify("Target window changed — typing cancelled")
                return
            }

            // #10: cue plays right before typing begins, signalling the paste.
            if cueEnabled {
                PasteCueSound.shared.play()
            }

            // #12: run the blocking loop on the single serial queue, bridged
            // back to the main actor for completion handling.
            let skipped: [Character] = await withCheckedContinuation { continuation in
                queue.async {
                    continuation.resume(returning: engine.type(text, using: layout, config: config))
                }
            }

            let wasCancelled = Task.isCancelled
            self.finishTyping()
            if !wasCancelled, !skipped.isEmpty {
                self.notify("Couldn't type \(skipped.count) character(s) not available in the \"\(layout.displayName)\" layout.")
            }
        }
    }

    /// #22: stops the lead-time countdown and any in-progress typing run.
    @objc private func stopTyping() {
        engine.cancel()
        typingTask?.cancel()
        finishTyping()
    }

    /// Clears the in-flight guard. Idempotent: safe to call from both the
    /// completion path and ``stopTyping``.
    private func finishTyping() {
        isTyping = false
        typingTask = nil
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(stopTyping) {
            return isTyping
        }
        return true
    }

    private func notify(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Tipsy"
        alert.informativeText = message
        alert.runModal()
    }
}
