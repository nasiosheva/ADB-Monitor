//
//  AppDelegate.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import AppKit

/// Lifecycle aplikasi sekaligus composition root: satu-satunya tempat yang mengenal tipe konkret.
@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var coordinator: AppCoordinator?

    /// Entry point eksplisit: `@main` saja hanya memanggil `NSApplicationMain` yang baru membuat delegate
    /// jika ada nib, sedangkan proyek ini tidak memakai nib. `static func main()` di kelas `@MainActor`
    /// berjalan di main actor, dan `NSApplication.delegate` weak sehingga instance harus dipegang `main()`.
    static func main() {
        let delegate = AppDelegate()
        let application = NSApplication.shared
        application.delegate = delegate
        application.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Saat dijadikan host unit test, jangan membuat item menu bar atau menjalankan adb sungguhan.
        guard NSClassFromString("XCTestCase") == nil else { return }

        NSApp.setActivationPolicy(.accessory)  // menu bar saja, tanpa ikon Dock
        NSApp.mainMenu = MainMenuBuilder.build()

        let coordinator = makeCoordinator()
        self.coordinator = coordinator
        coordinator.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.stop()
    }

    private func makeCoordinator() -> AppCoordinator {
        let preferences = UserDefaultsPreferences()
        let locator = ADBLocator()
        let launchAtLogin = LaunchAtLogin.makeDefault()
        let localizer = Localizer(provider: preferences)
        let service = ADBService(pathProvider: preferences,
                                 locator: locator,
                                 parser: DeviceListParser(),
                                 runner: ProcessManager())
        let scheduler = RunLoopScheduler()
        let monitor = DeviceMonitor(service: service,
                                    discovery: service,
                                    discoverySettings: preferences,
                                    intervalProvider: preferences,
                                    scheduler: scheduler)
        let alerts = AppKitAlertPresenter(localizer: localizer)
        let wireless = WirelessCoordinator(controller: service,
                                           switcher: WirelessSwitcher(controller: service, scheduler: scheduler),
                                           prompts: AppKitWirelessPrompter(localizer: localizer),
                                           alerts: alerts,
                                           monitor: monitor,
                                           localizer: localizer)

        let makePreferencesWindow: @MainActor () -> PreferencesWindowController = {
            PreferencesWindowController(preferences: preferences,
                                        locator: locator,
                                        launchAtLogin: launchAtLogin,
                                        localizer: localizer)
        }

        return AppCoordinator(monitor: monitor,
                              service: service,
                              alerts: alerts,
                              wireless: wireless,
                              settings: service,
                              localizer: localizer,
                              makeStatusBar: { StatusBarController(actionHandler: $0, localizer: localizer) },
                              makePreferencesWindow: makePreferencesWindow)
    }
}
