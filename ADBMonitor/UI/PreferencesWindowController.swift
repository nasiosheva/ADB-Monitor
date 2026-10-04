//
//  PreferencesWindowController.swift
//  ADBMonitor
//

import AppKit

/// Jendela Preferences: path ADB kustom dan interval refresh.
final class PreferencesWindowController: NSWindowController, NSTextFieldDelegate {

    private let preferences: PreferencesStoring
    private let locator: ADBLocating

    private let pathField = NSTextField()
    private let detectedLabel = NSTextField(labelWithString: "")
    private let intervalStepper = NSStepper()
    private let intervalLabel = NSTextField(labelWithString: "")

    init(preferences: PreferencesStoring, locator: ADBLocating) {
        self.preferences = preferences
        self.locator = locator

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 190),
                              styleMask: [.titled, .closable],
                              backing: .buffered,
                              defer: false)
        window.title = "ADB Monitor Preferences"
        window.isReleasedWhenClosed = false
        super.init(window: window)

        install(makeContent(), in: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Memuat nilai tersimpan lalu menampilkan jendela di depan.
    func present() {
        guard let window = window else { return }
        loadStoredValues()

        if !window.isVisible { window.center() }
        NSApp.activate(ignoringOtherApps: true)  // app accessory (tanpa Dock) harus diaktifkan manual
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Content

    private func makeContent() -> NSView {
        let form = NSGridView(views: [
            [NSTextField(labelWithString: "ADB path:"), makePathRow()],
            [NSGridCell.emptyContentView, makeDetectedLabel()],
            [NSTextField(labelWithString: "Refresh interval:"), makeIntervalRow()],
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
        pathField.placeholderString = "Auto-detect (leave empty)"
        pathField.delegate = self
        pathField.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let chooseButton = NSButton(title: "Choose…", target: self, action: #selector(chooseADB))
        return horizontalStack([pathField, chooseButton], spacing: 8)
    }

    private func makeDetectedLabel() -> NSView {
        detectedLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        detectedLabel.lineBreakMode = .byTruncatingMiddle
        return detectedLabel
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
        intervalLabel.widthAnchor.constraint(equalToConstant: 48).isActive = true
        return horizontalStack([intervalLabel, intervalStepper], spacing: 6)
    }

    private func makeButtonRow() -> NSView {
        let spacer = NSView()
        spacer.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: .horizontal)

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelButton.keyEquivalent = "\u{1b}"
        let saveButton = NSButton(title: "Save", target: self, action: #selector(save))
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

    // MARK: - State

    private func loadStoredValues() {
        pathField.stringValue = preferences.adbPath ?? ""
        intervalStepper.doubleValue = preferences.refreshInterval
        updateIntervalLabel()
        updateDetectedLabel()
    }

    private func updateIntervalLabel() {
        intervalLabel.stringValue = "\(Int(intervalStepper.doubleValue)) s"
    }

    private func updateDetectedLabel() {
        let custom = pathField.stringValue.trimmed
        if let found = locator.locate(customPath: custom.isEmpty ? nil : custom) {
            detectedLabel.stringValue = "Using: \(found)"
            detectedLabel.textColor = .secondaryLabelColor
        } else {
            detectedLabel.stringValue = custom.isEmpty ? "ADB not found" : "Not an executable file"
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
        panel.title = "Select adb executable"
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
        preferences.save(adbPath: pathField.stringValue, refreshInterval: intervalStepper.doubleValue)
        window?.close()
    }
}
