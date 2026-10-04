//
//  AppDelegate.swift
//  ADBMonitor
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
        let service = ADBService(pathProvider: preferences,
                                 locator: locator,
                                 parser: DeviceListParser(),
                                 runner: ProcessManager())
        let monitor = DeviceMonitor(service: service,
                                    intervalProvider: preferences,
                                    scheduler: RunLoopScheduler())

        let makePreferencesWindow: @MainActor () -> PreferencesWindowController = {
            PreferencesWindowController(preferences: preferences, locator: locator)
        }

        return AppCoordinator(monitor: monitor,
                              service: service,
                              alerts: AppKitAlertPresenter(),
                              makePreferencesWindow: makePreferencesWindow)
    }
}
