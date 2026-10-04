//
//  PreferencesWindowController.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import AppKit

/// Abstraction of the Preferences window, so `AppCoordinator` can be tested without showing a real window.
@MainActor
protocol PreferencesPresenting: AnyObject {
    /// Loads the stored values, then shows the window in front.
    func present()
}

/// Preferences window: custom ADB path, refresh interval, language, launch at login, Wi-Fi discovery, and
/// device notifications.
final class PreferencesWindowController: NSWindowController, NSTextFieldDelegate, PreferencesPresenting {

    private let preferences: PreferencesStoring
    private let locator: ADBLocating
    private let launchAtLogin: LaunchAtLoginControlling
    private let l10n: Localizing

    // Static labels are kept so their text can be replaced when the language changes.
    private let pathTitle = NSTextField(labelWithString: "")
    private let intervalTitle = NSTextField(labelWithString: "")
    private let languageTitle = NSTextField(labelWithString: "")
    private let startupTitle = NSTextField(labelWithString: "")
    private let wirelessTitle = NSTextField(labelWithString: "")
    private let notificationsTitle = NSTextField(labelWithString: "")
    private let chooseButton = NSButton(title: "", target: nil, action: nil)
    private let cancelButton = NSButton(title: "", target: nil, action: nil)
    private let saveButton = NSButton(title: "", target: nil, action: nil)

    private let pathField = NSTextField()
    private let detectedLabel = NSTextField(labelWithString: "")
    private let intervalStepper = NSStepper()
    private let intervalLabel = NSTextField(labelWithString: "")
    private let languagePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let launchCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let launchNote = NSTextField(labelWithString: "")
    private let wirelessCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let wirelessNote = NSTextField(labelWithString: "")
    private let notificationsCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let notificationsNote = NSTextField(labelWithString: "")

    init(preferences: PreferencesStoring,
         locator: ADBLocating,
         launchAtLogin: LaunchAtLoginControlling,
         localizer: Localizing) {
        self.preferences = preferences
        self.locator = locator
        self.launchAtLogin = launchAtLogin
        self.l10n = localizer

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 390),
                              styleMask: [.titled, .closable],
                              backing: .buffered,
                              defer: false)
        window.isReleasedWhenClosed = false
        super.init(window: window)

        install(makeContent(), in: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func present() {
        guard let window = window else { return }
        applyLocalizedStrings()
        loadStoredValues()

        if !window.isVisible { window.center() }
        NSApp.activate(ignoringOtherApps: true)  // an accessory app (no Dock icon) must be activated manually
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Content

    private func makeContent() -> NSView {
        let form = NSGridView(views: [
            [pathTitle, makePathRow()],
            [NSGridCell.emptyContentView, makeDetectedLabel()],
            [intervalTitle, makeIntervalRow()],
            [languageTitle, languagePopup],
            [startupTitle, launchCheckbox],
            [NSGridCell.emptyContentView, makeLaunchNote()],
            [wirelessTitle, wirelessCheckbox],
            [NSGridCell.emptyContentView, makeWirelessNote()],
            [notificationsTitle, notificationsCheckbox],
            [NSGridCell.emptyContentView, makeNotificationsNote()],
        ])
        form.rowSpacing = 10
        form.columnSpacing = 10
        form.column(at: 0).xPlacement = .trailing
        form.column(at: 1).xPlacement = .fill

        let root = NSStackView(views: [form, makeButtonRow()])
        root.orientation = .vertical
        root.alignment = .width
        root.spacing = 20
        return root
    }

    private func makePathRow() -> NSView {
        pathField.delegate = self
        pathField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        // Without a minimum width, the column follows the note text below it and the field can shrink to ~70 pt.
        pathField.widthAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true

        chooseButton.target = self
        chooseButton.action = #selector(chooseADB)
        return horizontalStack([pathField, chooseButton], spacing: 8)
    }

    private func makeDetectedLabel() -> NSView {
        detectedLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        detectedLabel.lineBreakMode = .byTruncatingMiddle
        return detectedLabel
    }

    private func makeLaunchNote() -> NSView {
        launchNote.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        launchNote.textColor = .secondaryLabelColor
        launchNote.lineBreakMode = .byTruncatingTail
        return launchNote
    }

    private func makeWirelessNote() -> NSView {
        wirelessNote.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        wirelessNote.textColor = .secondaryLabelColor
        wirelessNote.lineBreakMode = .byTruncatingTail
        return wirelessNote
    }

    private func makeNotificationsNote() -> NSView {
        notificationsNote.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        notificationsNote.textColor = .secondaryLabelColor
        notificationsNote.lineBreakMode = .byTruncatingTail
        return notificationsNote
    }

    private func makeIntervalRow() -> NSView {
        let range = RefreshIntervalLimits.range
        intervalStepper.minValue = range.lowerBound
        intervalStepper.maxValue = range.upperBound
        intervalStepper.increment = 1
        intervalStepper.valueWraps = false
        intervalStepper.target = self
        intervalStepper.action = #selector(intervalChanged)

        intervalLabel.alignment = .right
        intervalLabel.widthAnchor.constraint(equalToConstant: 64).isActive = true
        return horizontalStack([intervalLabel, intervalStepper], spacing: 6)
    }

    private func makeButtonRow() -> NSView {
        let spacer = NSView()
        spacer.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: .horizontal)

        cancelButton.target = self
        cancelButton.action = #selector(cancel)
        cancelButton.keyEquivalent = "\u{1b}"
        saveButton.target = self
        saveButton.action = #selector(save)
        saveButton.keyEquivalent = "\r"

        return horizontalStack([spacer, cancelButton, saveButton], spacing: 8)
    }

    private func horizontalStack(_ views: [NSView], spacing: CGFloat) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .horizontal
        stack.spacing = spacing
        return stack
    }

    private func install(_ content: NSView, in window: NSWindow) {
        guard let container = window.contentView else { return }
        content.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
        ])
    }

    // MARK: - Localization

    /// Applies the active language to all static text. Called every time the window opens,
    /// because the language can change while the window is closed.
    private func applyLocalizedStrings() {
        window?.title = l10n.text(.prefsWindowTitle)
        pathTitle.stringValue = l10n.text(.prefsAdbPath)
        intervalTitle.stringValue = l10n.text(.prefsRefreshInterval)
        languageTitle.stringValue = l10n.text(.prefsLanguage)
        startupTitle.stringValue = l10n.text(.prefsStartup)
        pathField.placeholderString = l10n.text(.prefsAdbPlaceholder)
        chooseButton.title = l10n.text(.prefsChoose)
        cancelButton.title = l10n.text(.commonCancel)
        saveButton.title = l10n.text(.prefsSave)
        launchCheckbox.title = l10n.text(.prefsLaunchAtLogin)
        wirelessTitle.stringValue = l10n.text(.prefsWireless)
        wirelessCheckbox.title = l10n.text(.prefsWirelessDiscovery)
        wirelessNote.stringValue = l10n.text(.prefsWirelessNote)
        notificationsTitle.stringValue = l10n.text(.prefsNotifications)
        notificationsCheckbox.title = l10n.text(.prefsNotifyDevices)
        notificationsNote.stringValue = l10n.text(.prefsNotifyNote)
    }

    private func rebuildLanguageMenu(selecting preference: LanguagePreference) {
        languagePopup.removeAllItems()
        languagePopup.addItem(withTitle: l10n.text(.prefsLanguageSystem))
        AppLanguage.allCases.forEach { languagePopup.addItem(withTitle: $0.autonym) }

        switch preference {
        case .system:
            languagePopup.selectItem(at: 0)
        case .explicit(let language):
            let index = AppLanguage.allCases.firstIndex(of: language).map { $0 + 1 } ?? 0
            languagePopup.selectItem(at: index)
        }
    }

    private func selectedLanguagePreference() -> LanguagePreference {
        let index = languagePopup.indexOfSelectedItem - 1   // item 0 is "follow system"
        guard AppLanguage.allCases.indices.contains(index) else { return .system }
        return .explicit(AppLanguage.allCases[index])
    }

    // MARK: - State

    private func loadStoredValues() {
        pathField.stringValue = preferences.adbPath ?? ""
        intervalStepper.doubleValue = preferences.refreshInterval
        updateIntervalLabel()
        updateDetectedLabel()
        rebuildLanguageMenu(selecting: preferences.languagePreference)
        wirelessCheckbox.state = preferences.wirelessDiscoveryEnabled ? .on : .off
        notificationsCheckbox.state = preferences.deviceNotificationsEnabled ? .on : .off
        loadLaunchAtLogin()
    }

    /// The login item state is re-read from the system each time the window opens; System Settings can change it.
    private func loadLaunchAtLogin() {
        let status = launchAtLogin.status
        launchCheckbox.state = status.isOn ? .on : .off
        launchCheckbox.isEnabled = status != .unsupported

        switch status {
        case .unsupported:
            launchNote.stringValue = l10n.text(.prefsLaunchUnsupported)
        case .requiresApproval:
            launchNote.stringValue = l10n.text(.prefsLaunchApproval)
        case .enabled, .disabled:
            launchNote.stringValue = ""
        }
    }

    /// Returns the error if the system rejected the change; `nil` if it succeeded or nothing changed.
    private func applyLaunchAtLogin() -> Error? {
        let wanted = launchCheckbox.state == .on
        guard launchCheckbox.isEnabled, wanted != launchAtLogin.status.isOn else { return nil }
        do {
            try launchAtLogin.setEnabled(wanted)
            return nil
        } catch {
            return error
        }
    }

    private func updateIntervalLabel() {
        intervalLabel.stringValue = l10n.text(.prefsSeconds, String(Int(intervalStepper.doubleValue)))
    }

    private func updateDetectedLabel() {
        let custom = pathField.stringValue.trimmed
        if let found = locator.locate(customPath: custom.isEmpty ? nil : custom) {
            detectedLabel.stringValue = l10n.text(.prefsUsing, found)
            detectedLabel.textColor = .secondaryLabelColor
        } else {
            detectedLabel.stringValue = l10n.text(custom.isEmpty ? .prefsAdbNotFound : .prefsNotExecutable)
            detectedLabel.textColor = .systemRed
        }
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        updateDetectedLabel()
    }

    // MARK: - Actions

    @objc private func chooseADB() {
        let panel = NSOpenPanel()
        panel.title = l10n.text(.prefsSelectAdbPanel)
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        pathField.stringValue = url.path
        updateDetectedLabel()
    }

    @objc private func intervalChanged() {
        updateIntervalLabel()
    }

    @objc private func cancel() {
        window?.close()
    }

    @objc private func save() {
        preferences.save(adbPath: pathField.stringValue,
                         refreshInterval: intervalStepper.doubleValue,
                         language: selectedLanguagePreference(),
                         wirelessDiscovery: wirelessCheckbox.state == .on,
                         deviceNotifications: notificationsCheckbox.state == .on)

        if let error = applyLaunchAtLogin() {
            // The other settings are already saved; the window stays open so the user sees this failure.
            applyLocalizedStrings()   // the language may have just changed
            loadStoredValues()
            showLaunchAtLoginError(error)
            return
        }
        window?.close()
    }

    private func showLaunchAtLoginError(_ error: Error) {
        guard let window = window else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = (error as? LaunchAtLoginError) == .unsupported
            ? l10n.text(.errorLaunchAtLoginUnsupported)
            : error.localizedDescription
        alert.beginSheetModal(for: window)
    }
}
