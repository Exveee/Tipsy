import AppKit

/// Menu bar controller: lets the user pick a layout and trigger typing of the
/// current clipboard into whatever window is focused after a short countdown.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let engine = KeystrokeEngine()
    private let layouts = Layouts.all
    private var activeLayout: KeyboardLayout

    /// Seconds to wait after triggering so the user can focus the target window.
    private let leadTime: TimeInterval = 3

    override init() {
        activeLayout = layouts[0]
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AccessibilityManager.ensureTrusted(prompt: true)
        buildStatusItem()
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
        let quit = NSMenuItem(title: "Quit Tipsy", action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
    }

    @objc private func selectLayout(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let layout = layouts.first(where: { $0.id == id }) else { return }
        activeLayout = layout
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
