import AppKit

/// Registers a fixed global hotkey (Cmd+Shift+T) that fires ``onTrigger``.
///
/// Uses `NSEvent` monitors rather than a Carbon hot-key so no extra entitlement
/// is needed: the global monitor delivers events while Tipsy is in the
/// background, and a local monitor covers the case where Tipsy itself is key.
/// Global monitors require Accessibility permission, which the app already
/// requests for keystroke synthesis.
@MainActor
final class HotkeyManager {

    /// Invoked on the main actor when the hotkey combo is pressed.
    var onTrigger: (() -> Void)?

    /// Virtual key code for the `T` key.
    private let keyCode: UInt16 = 17
    private let requiredFlags: NSEvent.ModifierFlags = [.command, .shift]

    private var globalMonitor: Any?
    private var localMonitor: Any?

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
    private func handle(_ event: NSEvent) {
        guard event.keyCode == keyCode else { return }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.isSuperset(of: requiredFlags) else { return }
        onTrigger?()
    }
}
