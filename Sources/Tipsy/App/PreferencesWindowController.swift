import AppKit

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

        // Hotkey checkbox
        hotkeyCheckbox.setButtonType(.switch)
        hotkeyCheckbox.title = "Enable global hotkey (⌘⇧T)"
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

        updateValueLabels()
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
}
