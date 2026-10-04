//
//  AppDelegate.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import AppKit

/// App lifecycle and composition root: the only place that knows the concrete types.
@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var coordinator: AppCoordinator?

    /// Explicit entry point: `@main` alone only calls `NSApplicationMain`, which creates the delegate
    /// only when a nib exists, and this project has no nib. `static func main()` in a `@MainActor`
    /// class runs on the main actor, and `NSApplication.delegate` is weak, so `main()` must hold the instance.
    static func main() {
        let delegate = AppDelegate()
        let application = NSApplication.shared
        application.delegate = delegate
        application.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // When hosted by unit tests, do not create a menu bar item or run a real adb.
        guard NSClassFromString("XCTestCase") == nil else { return }

        NSApp.setActivationPolicy(.accessory)  // menu bar only, no Dock icon
        NSApp.mainMenu = MainMenuBuilder.build()

        let coordinator = makeCoordinator()
        self.coordinator = coordinator
        coordinator.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.stop()
    }

    private func makeCoordinator() -> AppCoordinator {
        #if DEBUG
        // UI tests: adb is simulated and preferences are kept separate (see `App/UITesting`).
        if let environment = UITestEnvironment.current() {
            return UITestComposition.makeCoordinator(environment)
        }
        #endif

        let preferences = UserDefaultsPreferences()
        let locator = ADBLocator()
        let launchAtLogin = LaunchAtLogin.makeDefault()
        let localizer = Localizer(provider: preferences)
        let runner = ProcessManager()
        let service = ADBService(pathProvider: preferences,
                                 locator: locator,
                                 parser: DeviceListParser(),
                                 runner: runner)
        let fastboot = FastbootService(locator: ADBLocator(executableName: "fastboot"), runner: runner)
        let scheduler = RunLoopScheduler()
        let monitor = DeviceMonitor(service: service,
                                    discovery: service,
                                    fastboot: fastboot,
                                    discoverySettings: preferences,
                                    intervalProvider: preferences,
                                    scheduler: scheduler)
        let alerts = AppKitAlertPresenter(localizer: localizer)
        let wireless = WirelessCoordinator(controller: service,
                                           switcher: WirelessSwitcher(controller: service, scheduler: scheduler),
                                           prompts: AppKitWirelessPrompter(localizer: localizer),
                                           qrPairer: WirelessQRPairer(discovery: service, controller: service,
                                                                      scheduler: scheduler),
                                           qrWindow: AppKitPairingQRPresenter(localizer: localizer),
                                           alerts: alerts,
                                           monitor: monitor,
                                           localizer: localizer)

        let tools = ToolsCoordinator(server: service, fastboot: fastboot, alerts: alerts, monitor: monitor,
                                     localizer: localizer)

        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let scrcpyLocator = ADBLocator(executableName: "scrcpy")
        let launcher = ProcessLauncher()
        let screen = ScreenCoordinator(screenshots: service,
                                       recorder: ScrcpyRecorder(scrcpyLocator: scrcpyLocator, adbLocator: locator,
                                                                pathProvider: preferences, launcher: launcher,
                                                                scheduler: scheduler),
                                       mirror: ScrcpyMirror(scrcpyLocator: scrcpyLocator, adbLocator: locator,
                                                            pathProvider: preferences, launcher: launcher,
                                                            scheduler: scheduler),
                                       files: FinderFileRevealer(),
                                       alerts: alerts,
                                       localizer: localizer,
                                       directory: desktop)
        let changeNotifier = DeviceChangeNotifier(settings: preferences,
                                                  notifier: UserNotificationNotifier(localizer: localizer))

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
                              tools: tools,
                              screen: screen,
                              settings: service,
                              localizer: localizer,
                              detailsTracker: DeviceDetailsTracker(reader: service),
                              changeTracker: changeNotifier,
                              makeStatusBar: { StatusBarController(actionHandler: $0, localizer: localizer) },
                              makePreferencesWindow: makePreferencesWindow)
    }
}
