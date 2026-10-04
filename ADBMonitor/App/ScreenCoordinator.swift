//
//  ScreenCoordinator.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// Flows for the screen tools of a device: take a screenshot, record the screen, and mirror the screen.
/// None needs a confirmation, because none changes the device.
@MainActor
final class ScreenCoordinator: ScreenActionHandling, RecordingStateReporting {

    var onRecordingChange: ((Set<String>) -> Void)?

    private let screenshots: ScreenshotTaking
    private let recorder: ScreenRecording
    private let mirror: ScreenMirroring
    private let files: FileRevealing
    private let alerts: AlertPresenting
    private let l10n: Localizing
    private let directory: URL
    private let now: () -> Date
    private let timeZone: TimeZone
    /// Serials with a screenshot in progress; a second click on the same device is ignored.
    private var capturing: Set<String> = []
    /// Serials that are being recorded, reported to the menu so it can show "Stop Recording".
    private var recording: Set<String> = [] {
        didSet { if recording != oldValue { onRecordingChange?(recording) } }
    }

    init(screenshots: ScreenshotTaking,
         recorder: ScreenRecording,
         mirror: ScreenMirroring,
         files: FileRevealing,
         alerts: AlertPresenting,
         localizer: Localizing,
         directory: URL,
         now: @escaping () -> Date = Date.init,
         timeZone: TimeZone = .current) {
        self.screenshots = screenshots
        self.recorder = recorder
        self.mirror = mirror
        self.files = files
        self.alerts = alerts
        self.l10n = localizer
        self.directory = directory
        self.now = now
        self.timeZone = timeZone
    }

    // MARK: - ScreenActionHandling

    func statusMenu(didRequestScreenshotOf device: ADBDevice) {
        guard capturing.insert(device.serial).inserted else { return }
        let destination = directory.appendingPathComponent(fileName(for: device, at: now()))

        screenshots.takeScreenshot(of: device.serial, to: destination) { [weak self] result in
            guard let self = self else { return }
            self.capturing.remove(device.serial)
            switch result {
            case .success:
                self.files.reveal(destination)
            case .failure(let error):
                self.alerts.showError(title: self.l10n.text(.screenshotFailureTitle, device.displayName),
                                      message: self.l10n.message(for: error))
            }
        }
    }

    /// Starts a recording, or stops the one that is running for this device.
    func statusMenu(didRequestToggleRecordingOf device: ADBDevice) {
        guard !recorder.isRecording(serial: device.serial) else {
            recorder.stop(serial: device.serial)
            return
        }
        let destination = directory.appendingPathComponent(
            fileName(prefix: "ADB Recording", extension: "mp4", for: device, at: now()))

        recording.insert(device.serial)
        // Called when the recording has ended (stopped, time limit, or failure), or at once if it cannot start.
        recorder.start(serial: device.serial, to: destination) { [weak self] result in
            guard let self = self else { return }
            self.recording.remove(device.serial)
            switch result {
            case .success:
                self.files.reveal(destination)
            case .failure(let error):
                self.alerts.showError(title: self.l10n.text(.recordFailureTitle, device.displayName),
                                      message: self.l10n.message(for: error))
            }
        }
    }

    func statusMenu(didRequestMirror device: ADBDevice) {
        mirror.mirror(serial: device.serial) { [weak self] result in
            guard let self = self, case .failure(let error) = result else { return }
            self.alerts.showError(title: self.l10n.text(.mirrorFailureTitle, device.displayName),
                                  message: self.l10n.message(for: error))
        }
    }

    // MARK: - File name

    func fileName(for device: ADBDevice, at date: Date) -> String {
        fileName(prefix: "ADB Screenshot", extension: "png", for: device, at: date)
    }

    /// `ADB Screenshot Pixel_3a 2026-10-04 at 18.30.12.png`. Characters that are awkward in file names
    /// (`:` and `/` in a Wi-Fi serial, for example) become `-`.
    func fileName(prefix: String, extension fileExtension: String, for device: ADBDevice, at date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._- "))
        let name = String(device.displayName.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
        return "\(prefix) \(name) \(formatter.string(from: date)).\(fileExtension)"
    }
}
