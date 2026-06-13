import AppKit

/// Registers a configurable global hotkey that fires ``onTrigger``.
///
/// Uses `NSEvent` monitors rather than a Carbon hot-key so no extra entitlement
/// is needed: the global monitor delivers events while Tipsy is in the
/// background, and a local monitor covers the case where Tipsy itself is key.
/// Global monitors require Accessibility permission, which the app already
/// requests for keystroke synthesis.
///
/// The binding (``keyCode`` + ``modifiers``) is set by the app from persisted
/// settings via ``configure(keyCode:modifiers:)`` and may change live.
@MainActor
final class HotkeyManager {

    /// Invoked on the main actor when the hotkey combo is pressed.
    var onTrigger: (() -> Void)?

    /// Virtual key code to match. Defaults to `17` (the `T` key).
    var keyCode: UInt16 = 17

    /// Modifier flags that must match exactly (within command/control/option/
    /// shift). Defaults to ⌘⇧. An empty set never matches.
    var modifiers: NSEvent.ModifierFlags = [.command, .shift]

    /// The four modifiers considered when matching; caps lock / fn are ignored.
    private let relevantFlags: NSEvent.ModifierFlags = [.command, .control, .option, .shift]

    private var globalMonitor: Any?
    private var localMonitor: Any?

    /// Updates the live binding. Safe to call while enabled.
    func configure(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// Whether the monitors are currently installed.
    var isEnabled: Bool { globalMonitor != nil || localMonitor != nil }

    /// Installs the global and local key-down monitors. No-op if already enabled.
    func enable() {
        guard !isEnabled else { return }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    /// Re-installs the monitors if currently enabled. Needed because a global
    /// monitor added while the process was untrusted never starts firing once
    /// Accessibility is granted later — only a freshly added monitor observes
    /// events. Call after trust is acquired. No-op if disabled.
    func reload() {
        guard isEnabled else { return }
        disable()
        enable()
    }

    /// Removes the monitors. No-op if already disabled.
    func disable() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    /// Fires ``onTrigger`` when `event` matches the configured combo.
    ///
    /// Requires an exact match of the command/control/option/shift modifiers
    /// (caps lock / fn ignored). A binding with no modifiers never matches, so
    /// plain keys are not hijacked.
    private func handle(_ event: NSEvent) {
        let required = modifiers.intersection(relevantFlags)
        guard !required.isEmpty else { return }
        guard event.keyCode == keyCode else { return }
        let flags = event.modifierFlags.intersection(relevantFlags)
        guard flags == required else { return }
        onTrigger?()
    }
}
