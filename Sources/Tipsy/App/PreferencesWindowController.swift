import AppKit
import TipsyKit

/// Code-built (no nib) preferences window. Edits write through to ``Settings``
/// immediately and notify ``onChange`` so the app can re-apply them live.
@MainActor
final class PreferencesWindowController: NSWindowController, NSWindowDelegate {

    /// Called after any setting changes so AppDelegate can re-apply them.
    var onChange: (() -> Void)?

    private let layoutPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let characterDelaySlider = NSSlider()
    private let characterDelayLabel = NSTextField(labelWithString: "")
    private let jitterSlider = NSSlider()
    private let jitterLabel = NSTextField(labelWithString: "")
    private let unicodeFallbackCheckbox = NSButton()
    private let leadTimeSlider = NSSlider()
    private let leadTimeLabel = NSTextField(labelWithString: "")
    private let hotkeyCheckbox = NSButton()
    private let hotkeyRecorderButton = NSButton()

    /// Local key-down monitor installed only while recording a new combo.
    private var recordingMonitor: Any?
    /// Button title to restore if recording is cancelled.
    private var titleBeforeRecording: String?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Tipsy Preferences"
        self.init(window: window)
        window.delegate = self
        buildUI()
        loadFromSettings()
    }

    /// Shows the window, reusing the existing one and bringing it to front.
    func present() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - UI construction

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -20)
        ])

        // Layout popup
        for layout in Layouts.all {
            layoutPopup.addItem(withTitle: layout.displayName)
            layoutPopup.lastItem?.representedObject = layout.id
        }
        layoutPopup.target = self
        layoutPopup.action = #selector(layoutChanged)
        stack.addArrangedSubview(labeledRow("Default layout:", layoutPopup))

        // Character delay slider (0–0.2s)
        characterDelaySlider.minValue = 0
        characterDelaySlider.maxValue = 0.2
        characterDelaySlider.target = self
        characterDelaySlider.action = #selector(characterDelayChanged)
        characterDelaySlider.widthAnchor.constraint(equalToConstant: 180).isActive = true
        stack.addArrangedSubview(labeledRow("Character delay:", characterDelaySlider, valueLabel: characterDelayLabel))

        // Jitter slider (0–0.1s)
        jitterSlider.minValue = 0
        jitterSlider.maxValue = 0.1
        jitterSlider.target = self
        jitterSlider.action = #selector(jitterChanged)
        jitterSlider.widthAnchor.constraint(equalToConstant: 180).isActive = true
        stack.addArrangedSubview(labeledRow("Jitter:", jitterSlider, valueLabel: jitterLabel))

        // Lead time slider (0–10s)
        leadTimeSlider.minValue = 0
        leadTimeSlider.maxValue = 10
        leadTimeSlider.target = self
        leadTimeSlider.action = #selector(leadTimeChanged)
        leadTimeSlider.widthAnchor.constraint(equalToConstant: 180).isActive = true
        stack.addArrangedSubview(labeledRow("Lead time:", leadTimeSlider, valueLabel: leadTimeLabel))

        // Unicode fallback checkbox
        unicodeFallbackCheckbox.setButtonType(.switch)
        unicodeFallbackCheckbox.title = "Type unmapped characters as Unicode"
        unicodeFallbackCheckbox.target = self
        unicodeFallbackCheckbox.action = #selector(unicodeFallbackChanged)
        stack.addArrangedSubview(unicodeFallbackCheckbox)

        // Hotkey recorder
        hotkeyRecorderButton.bezelStyle = .rounded
        hotkeyRecorderButton.setButtonType(.momentaryPushIn)
        hotkeyRecorderButton.target = self
        hotkeyRecorderButton.action = #selector(hotkeyRecorderClicked)
        hotkeyRecorderButton.widthAnchor.constraint(equalToConstant: 120).isActive = true
        stack.addArrangedSubview(labeledRow("Trigger hotkey:", hotkeyRecorderButton))

        // Hotkey checkbox
        hotkeyCheckbox.setButtonType(.switch)
        hotkeyCheckbox.title = "Enable global hotkey"
        hotkeyCheckbox.target = self
        hotkeyCheckbox.action = #selector(hotkeyChanged)
        stack.addArrangedSubview(hotkeyCheckbox)
    }

    /// Builds a horizontal row: a leading label, a control, and an optional
    /// trailing value label.
    private func labeledRow(_ title: String,
                            _ control: NSView,
                            valueLabel: NSTextField? = nil) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.widthAnchor.constraint(equalToConstant: 110).isActive = true

        let row = NSStackView(views: [label, control])
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY
        if let valueLabel {
            valueLabel.widthAnchor.constraint(equalToConstant: 48).isActive = true
            row.addArrangedSubview(valueLabel)
        }
        return row
    }

    // MARK: - Loading

    private func loadFromSettings() {
        let index = Layouts.all.firstIndex { $0.id == Settings.layoutID } ?? 0
        layoutPopup.selectItem(at: index)

        characterDelaySlider.doubleValue = Settings.characterDelay
        jitterSlider.doubleValue = Settings.jitter
        leadTimeSlider.doubleValue = Settings.leadTime
        unicodeFallbackCheckbox.state = Settings.unicodeFallback ? .on : .off
        hotkeyCheckbox.state = Settings.hotkeyEnabled ? .on : .off
        hotkeyRecorderButton.title = currentHotkeyTitle()

        updateValueLabels()
    }

    /// Display string for the currently persisted trigger combo.
    private func currentHotkeyTitle() -> String {
        Self.hotkeyDisplayString(
            keyCode: UInt16(Settings.hotkeyKeyCode),
            modifiers: NSEvent.ModifierFlags(rawValue: Settings.hotkeyModifiers)
        )
    }

    private func updateValueLabels() {
        characterDelayLabel.stringValue = String(format: "%.3fs", Settings.characterDelay)
        jitterLabel.stringValue = String(format: "%.3fs", Settings.jitter)
        leadTimeLabel.stringValue = String(format: "%.1fs", Settings.leadTime)
    }

    // MARK: - Actions

    @objc private func layoutChanged() {
        if let id = layoutPopup.selectedItem?.representedObject as? String {
            Settings.layoutID = id
        }
        onChange?()
    }

    @objc private func characterDelayChanged() {
        Settings.characterDelay = characterDelaySlider.doubleValue
        updateValueLabels()
        onChange?()
    }

    @objc private func jitterChanged() {
        Settings.jitter = jitterSlider.doubleValue
        updateValueLabels()
        onChange?()
    }

    @objc private func leadTimeChanged() {
        Settings.leadTime = leadTimeSlider.doubleValue
        updateValueLabels()
        onChange?()
    }

    @objc private func unicodeFallbackChanged() {
        Settings.unicodeFallback = unicodeFallbackCheckbox.state == .on
        onChange?()
    }

    @objc private func hotkeyChanged() {
        Settings.hotkeyEnabled = hotkeyCheckbox.state == .on
        onChange?()
    }

    // MARK: - Hotkey recording

    @objc private func hotkeyRecorderClicked() {
        if recordingMonitor != nil {
            // A second click cancels an in-progress recording.
            cancelRecording()
            return
        }
        titleBeforeRecording = hotkeyRecorderButton.title
        hotkeyRecorderButton.title = "Press keys…"

        let relevant: NSEvent.ModifierFlags = [.command, .control, .option, .shift]
        recordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let mods = event.modifierFlags.intersection(relevant)
            // Escape or a key with no relevant modifier cancels.
            if event.keyCode == 53 || mods.isEmpty {
                self.cancelRecording()
                return nil
            }
            Settings.hotkeyKeyCode = Int(event.keyCode)
            Settings.hotkeyModifiers = mods.rawValue
            self.finishRecording()
            self.hotkeyRecorderButton.title = self.currentHotkeyTitle()
            self.onChange?()
            return nil
        }
    }

    /// Removes the recording monitor without changing the stored binding.
    private func finishRecording() {
        if let recordingMonitor {
            NSEvent.removeMonitor(recordingMonitor)
            self.recordingMonitor = nil
        }
        titleBeforeRecording = nil
    }

    /// Aborts recording and restores the previous button title.
    private func cancelRecording() {
        let restore = titleBeforeRecording
        finishRecording()
        hotkeyRecorderButton.title = restore ?? currentHotkeyTitle()
    }

    // MARK: - Formatting

    /// Formats a `(keyCode, modifiers)` pair into a human-readable combo such as
    /// `⌘⇧T`. Modifier symbols are emitted in the order ⌃⌥⇧⌘.
    static func hotkeyDisplayString(keyCode: UInt16,
                                    modifiers: NSEvent.ModifierFlags) -> String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        result += keyName(for: keyCode)
        return result
    }

    /// Maps common virtual key codes to display names, with a `keyN` fallback.
    private static func keyName(for keyCode: UInt16) -> String {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 28: return "8"
        case 29: return "0"
        case 31: return "O"
        case 32: return "U"
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 40: return "K"
        case 45: return "N"
        case 46: return "M"
        case 48: return "⇥"   // Tab
        case 49: return "Space"
        case 36: return "↩"   // Return
        case 51: return "⌫"   // Delete
        case 53: return "⎋"   // Escape
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        default: return "key\(keyCode)"
        }
    }
}
