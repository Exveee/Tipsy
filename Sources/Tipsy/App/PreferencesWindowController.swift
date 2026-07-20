import AppKit
import TipsyKit

/// Code-built (no nib) preferences window. Edits write through to ``Settings``
/// immediately and notify ``onChange`` so the app can re-apply them live.
@MainActor
final class PreferencesWindowController: NSWindowController, NSWindowDelegate {

    /// Called after any setting changes so AppDelegate can re-apply them.
    var onChange: (() -> Void)?

    private let targetPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let layoutPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let characterDelaySlider = NSSlider()
    private let characterDelayLabel = NSTextField(labelWithString: "")
    private let jitterSlider = NSSlider()
    private let jitterLabel = NSTextField(labelWithString: "")
    private let interEventOverrideCheckbox = NSButton()
    private let interEventDelaySlider = NSSlider()
    private let interEventDelayLabel = NSTextField(labelWithString: "")
    private let normalizationCheckbox = NSButton()
    private let unicodeFallbackCheckbox = NSButton()
    private let leadTimeSlider = NSSlider()
    private let leadTimeLabel = NSTextField(labelWithString: "")
    private let hotkeyCheckbox = NSButton()
    private let hotkeyRecorderButton = NSButton()
    private let cueSoundCheckbox = NSButton()
    private let loginItemCheckbox = NSButton()
    private let cueVariantPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let cueVolumeSlider = NSSlider()
    private let cueVolumeLabel = NSTextField(labelWithString: "")
    private let cueTestButton = NSButton()

    /// Local key-down monitor installed only while recording a new combo.
    private var recordingMonitor: Any?
    /// Button title to restore if recording is cancelled.
    private var titleBeforeRecording: String?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 500),
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

        // Target profile popup (drives layout filtering + Unicode fallback)
        for profile in TargetProfile.allCases {
            targetPopup.addItem(withTitle: profile.displayName)
            targetPopup.lastItem?.representedObject = profile.rawValue
        }
        targetPopup.target = self
        targetPopup.action = #selector(targetChanged)
        stack.addArrangedSubview(labeledRow("Target:", targetPopup))

        // Layout popup (items filled per profile in rebuildLayoutPopup)
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

        // Event pacing: a checkbox to override the profile default, plus a
        // slider in milliseconds (0–50 ms).
        interEventOverrideCheckbox.setButtonType(.switch)
        interEventOverrideCheckbox.title = "Override event pacing"
        interEventOverrideCheckbox.target = self
        interEventOverrideCheckbox.action = #selector(interEventOverrideChanged)
        stack.addArrangedSubview(interEventOverrideCheckbox)

        interEventDelaySlider.minValue = 0
        interEventDelaySlider.maxValue = 50   // milliseconds
        interEventDelaySlider.target = self
        interEventDelaySlider.action = #selector(interEventDelayChanged)
        interEventDelaySlider.widthAnchor.constraint(equalToConstant: 180).isActive = true
        stack.addArrangedSubview(labeledRow("Event delay:", interEventDelaySlider, valueLabel: interEventDelayLabel))

        // Normalize typographic characters
        normalizationCheckbox.setButtonType(.switch)
        normalizationCheckbox.title = "Normalize typographic characters"
        normalizationCheckbox.target = self
        normalizationCheckbox.action = #selector(normalizationChanged)
        stack.addArrangedSubview(normalizationCheckbox)

        // Unicode fallback checkbox
        unicodeFallbackCheckbox.setButtonType(.switch)
        unicodeFallbackCheckbox.title = "Type unmapped characters as Unicode"
        unicodeFallbackCheckbox.target = self
        unicodeFallbackCheckbox.action = #selector(unicodeFallbackChanged)
        stack.addArrangedSubview(unicodeFallbackCheckbox)

        // Cue sound checkbox
        cueSoundCheckbox.setButtonType(.switch)
        cueSoundCheckbox.title = "Play cue sound before typing"
        cueSoundCheckbox.target = self
        cueSoundCheckbox.action = #selector(cueSoundChanged)
        stack.addArrangedSubview(cueSoundCheckbox)

        // Cue motif popup
        for variant in CueVariant.allCases {
            cueVariantPopup.addItem(withTitle: variant.displayName)
            cueVariantPopup.lastItem?.representedObject = variant.rawValue
        }
        cueVariantPopup.target = self
        cueVariantPopup.action = #selector(cueVariantChanged)
        stack.addArrangedSubview(labeledRow("Cue sound:", cueVariantPopup))

        // Cue volume slider (0–1)
        cueVolumeSlider.minValue = 0
        cueVolumeSlider.maxValue = 1
        cueVolumeSlider.target = self
        cueVolumeSlider.action = #selector(cueVolumeChanged)
        cueVolumeSlider.widthAnchor.constraint(equalToConstant: 180).isActive = true
        stack.addArrangedSubview(labeledRow("Cue volume:", cueVolumeSlider, valueLabel: cueVolumeLabel))

        // Cue test button
        cueTestButton.bezelStyle = .rounded
        cueTestButton.title = "Test sound"
        cueTestButton.target = self
        cueTestButton.action = #selector(cueTestClicked)
        stack.addArrangedSubview(labeledRow("", cueTestButton))

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

        // Start at login checkbox
        loginItemCheckbox.setButtonType(.switch)
        loginItemCheckbox.title = "Start Tipsy at login"
        loginItemCheckbox.target = self
        loginItemCheckbox.action = #selector(loginItemChanged)
        stack.addArrangedSubview(loginItemCheckbox)
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

    /// Public re-entry point so ``AppDelegate`` can refresh an open window after
    /// the menu changes the profile or layout.
    func reloadFromSettings() {
        loadFromSettings()
    }

    private func loadFromSettings() {
        let profile = Settings.targetProfile
        let profileIndex = TargetProfile.allCases.firstIndex(of: profile) ?? 0
        targetPopup.selectItem(at: profileIndex)

        rebuildLayoutPopup(for: profile)

        characterDelaySlider.doubleValue = Settings.characterDelay
        jitterSlider.doubleValue = Settings.jitter
        leadTimeSlider.doubleValue = Settings.leadTime

        // Event pacing: overridden when a value is stored; otherwise show the
        // profile default (greyed out).
        let override = Settings.interEventDelay
        interEventOverrideCheckbox.state = override != nil ? .on : .off
        let seconds = override ?? profile.defaultInterEventDelay
        interEventDelaySlider.doubleValue = seconds * 1000   // seconds → ms
        interEventDelaySlider.isEnabled = override != nil

        normalizationCheckbox.state = Settings.normalizationEnabled ? .on : .off
        updateUnicodeFallbackAvailability(for: profile)

        unicodeFallbackCheckbox.state = Settings.unicodeFallback ? .on : .off
        cueSoundCheckbox.state = Settings.cueSoundEnabled ? .on : .off
        let variantIndex = CueVariant.allCases.firstIndex {
            $0.rawValue == Settings.cueVariant
        } ?? 0
        cueVariantPopup.selectItem(at: variantIndex)
        cueVolumeSlider.doubleValue = Settings.cueVolume
        hotkeyCheckbox.state = Settings.hotkeyEnabled ? .on : .off
        loginItemCheckbox.state = LoginItem.isEnabled ? .on : .off
        hotkeyRecorderButton.title = currentHotkeyTitle()

        updateValueLabels()
    }

    /// Display string for the currently persisted trigger combo.
    private func currentHotkeyTitle() -> String {
        HotkeyFormat.display(
            keyCode: UInt16(Settings.hotkeyKeyCode),
            modifiers: NSEvent.ModifierFlags(rawValue: Settings.hotkeyModifiers)
        )
    }

    private func updateValueLabels() {
        characterDelayLabel.stringValue = String(format: "%.3fs", Settings.characterDelay)
        jitterLabel.stringValue = String(format: "%.3fs", Settings.jitter)
        leadTimeLabel.stringValue = String(format: "%.1fs", Settings.leadTime)
        cueVolumeLabel.stringValue = "\(Int(Settings.cueVolume * 100))%"
        interEventDelayLabel.stringValue = String(format: "%.0f ms", interEventDelaySlider.doubleValue)
    }

    /// Rebuilds the layout popup to only the layouts valid for `profile`, then
    /// selects the active one (mirrors the menu's per-profile filtering).
    private func rebuildLayoutPopup(for profile: TargetProfile) {
        layoutPopup.removeAllItems()
        for layout in Layouts.matching(kind: profile.layoutKind) {
            layoutPopup.addItem(withTitle: layout.displayName)
            layoutPopup.lastItem?.representedObject = layout.id
        }
        let index = layoutPopup.itemArray.firstIndex {
            $0.representedObject as? String == Settings.layoutID
        } ?? 0
        layoutPopup.selectItem(at: index)
    }

    /// The Unicode fallback is unusable on a remote console (clients see key
    /// code 0 as the `A` key), so the checkbox is disabled there with an
    /// explanatory tooltip.
    private func updateUnicodeFallbackAvailability(for profile: TargetProfile) {
        let allowed = profile.allowsUnicodeFallback
        unicodeFallbackCheckbox.isEnabled = allowed
        unicodeFallbackCheckbox.toolTip = allowed ? nil :
            "Unavailable for a remote console: KVM/VNC clients see the fallback's key code 0 as the A key, so every unmapped character would arrive as a stray “a”."
    }

    // MARK: - Actions

    @objc private func targetChanged() {
        guard let raw = targetPopup.selectedItem?.representedObject as? String,
              let profile = TargetProfile(rawValue: raw) else { return }
        Settings.targetProfile = profile
        // Keep the layout valid for the new profile; persist any auto-reselect.
        Settings.layoutID = Layouts.resolvedLayoutID(for: profile, current: Settings.layoutID)
        rebuildLayoutPopup(for: profile)
        updateUnicodeFallbackAvailability(for: profile)
        // Refresh the pacing slider's default/greyed state for the new profile.
        if Settings.interEventDelay == nil {
            interEventDelaySlider.doubleValue = profile.defaultInterEventDelay * 1000
            updateValueLabels()
        }
        onChange?()
    }

    @objc private func layoutChanged() {
        if let id = layoutPopup.selectedItem?.representedObject as? String {
            Settings.layoutID = id
        }
        onChange?()
    }

    @objc private func interEventOverrideChanged() {
        if interEventOverrideCheckbox.state == .on {
            // Adopt the slider's current (profile-default) value as the override.
            Settings.interEventDelay = interEventDelaySlider.doubleValue / 1000
            interEventDelaySlider.isEnabled = true
        } else {
            Settings.interEventDelay = nil
            interEventDelaySlider.isEnabled = false
            interEventDelaySlider.doubleValue = Settings.targetProfile.defaultInterEventDelay * 1000
        }
        updateValueLabels()
        onChange?()
    }

    @objc private func interEventDelayChanged() {
        Settings.interEventDelay = interEventDelaySlider.doubleValue / 1000   // ms → seconds
        updateValueLabels()
        onChange?()
    }

    @objc private func normalizationChanged() {
        Settings.normalizationEnabled = normalizationCheckbox.state == .on
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

    @objc private func cueSoundChanged() {
        Settings.cueSoundEnabled = cueSoundCheckbox.state == .on
        if Settings.cueSoundEnabled { PasteCueSound.shared.play() }  // preview
        onChange?()
    }

    @objc private func cueVariantChanged() {
        if let raw = cueVariantPopup.selectedItem?.representedObject as? String {
            Settings.cueVariant = raw
        }
        PasteCueSound.shared.play()  // preview the chosen motif
        onChange?()
    }

    @objc private func cueVolumeChanged() {
        Settings.cueVolume = cueVolumeSlider.doubleValue
        updateValueLabels()
        // No auto-preview while dragging; use "Test sound".
        onChange?()
    }

    @objc private func cueTestClicked() {
        PasteCueSound.shared.play(
            variant: CueVariant(rawValue: Settings.cueVariant) ?? .rising,
            volume: Settings.cueVolume
        )
    }

    @objc private func hotkeyChanged() {
        Settings.hotkeyEnabled = hotkeyCheckbox.state == .on
        onChange?()
    }

    @objc private func loginItemChanged() {
        let enable = loginItemCheckbox.state == .on
        do {
            try LoginItem.setEnabled(enable)
        } catch {
            // Revert the checkbox and report why (e.g. running unbundled).
            loginItemCheckbox.state = LoginItem.isEnabled ? .on : .off
            let alert = NSAlert()
            alert.messageText = "Couldn't change login item"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    // MARK: - Window lifecycle

    /// Closing the window mid-recording must tear down the local key monitor;
    /// otherwise it lingers for the process lifetime and silently rebinds the
    /// hotkey on the next qualifying key-down. `cancelRecording()` no-ops when
    /// no monitor is installed.
    func windowWillClose(_ notification: Notification) {
        cancelRecording()
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

}
