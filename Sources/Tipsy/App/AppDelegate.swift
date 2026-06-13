import AppKit
import TipsyKit

/// Menu bar controller: lets the user pick a layout and trigger typing of the
/// current clipboard into whatever window is focused after a short countdown.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let engine = KeystrokeEngine()
    private let layouts = Layouts.all
    private var activeLayout: KeyboardLayout

    /// Seconds to wait after triggering so the user can focus the target window.
    private var leadTime: TimeInterval = 3

    private let hotkey = HotkeyManager()
    private var preferences: PreferencesWindowController?

    override init() {
        activeLayout = layouts[0]
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AccessibilityManager.ensureTrusted(prompt: true)
        applySettings()
        buildStatusItem()

        hotkey.onTrigger = { [weak self] in self?.typeClipboard() }
        applyHotkeyState()
    }

    /// Loads persisted settings into the engine, lead time, and active layout.
    private func applySettings() {
        engine.characterDelay = Settings.characterDelay
        engine.jitter = Settings.jitter
        engine.unicodeFallback = Settings.unicodeFallback
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
        statusItem.button?.title = "⌨︎"
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let type = NSMenuItem(title: "Type Clipboard (\(Int(leadTime))s)",
                              action: #selector(typeClipboard), keyEquivalent: "t")
        type.target = self
        menu.addItem(type)
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
        guard let text = ClipboardReader.text(), !text.isEmpty else {
            notify("Clipboard is empty")
            return
        }
        guard AccessibilityManager.isTrusted else {
            notify("Grant Accessibility permission in System Settings")
            return
        }
        let layout = activeLayout
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + leadTime) { [engine] in
            engine.type(text, using: layout)
        }
    }

    private func notify(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Tipsy"
        alert.informativeText = message
        alert.runModal()
    }
}
