//
//  UITestComposition.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

#if DEBUG
import AppKit

/// A `ProcessRunning` that runs no process: answers come from `FakeADBWorld`,
/// and every command is recorded (one line per command) so UI tests can check what was sent.
final class ScriptedProcessRunner: ProcessRunning {

    private let world: FakeADBWorld
    private let logURL: URL?

    init(world: FakeADBWorld, logURL: URL?) {
        self.world = world
        self.logURL = logURL
        if let logURL = logURL {
            try? Data().write(to: logURL)   // start from an empty log on every launch
        }
    }

    func run(executable: String,
             arguments: [String],
             timeout: TimeInterval,
             completion: @escaping (Result<ProcessOutput, ProcessError>) -> Void) {
        record("adb " + arguments.joined(separator: " "))
        let output = world.run(arguments)
        let result = ProcessOutput(stdout: output.stdout, stderr: output.stderr, exitCode: output.exitCode)
        // Asynchronous like `ProcessManager`, which delivers results on the main queue.
        DispatchQueue.main.async { completion(.success(result)) }
    }

    private func record(_ line: String) {
        guard let logURL = logURL, let data = (line + "\n").data(using: .utf8),
              let handle = try? FileHandle(forWritingTo: logURL) else { return }
        handle.seekToEndOfFile()
        handle.write(data)
        try? handle.close()
    }
}

struct FixedADBLocator: ADBLocating {
    let path: String?
    func locate(customPath: String?) -> String? { path }
}

/// In-memory login item state, so UI tests never register a real login item.
final class InMemoryLaunchAtLogin: LaunchAtLoginControlling {
    var status: LaunchAtLoginStatus = .disabled
    func setEnabled(_ enabled: Bool) throws { status = enabled ? .enabled : .disabled }
}

/// Assembles the app with a simulated `adb`, separate preferences, and a fake login item.
@MainActor
enum UITestComposition {

    static func makeCoordinator(_ environment: UITestEnvironment) -> AppCoordinator {
        let defaults = UserDefaults(suiteName: environment.defaultsSuiteName) ?? .standard
        defaults.removePersistentDomain(forName: environment.defaultsSuiteName)
        let preferences = UserDefaultsPreferences(defaults: defaults)
        preferences.save(adbPath: nil, refreshInterval: 1, language: .explicit(environment.language),
                         wirelessDiscovery: true)

        let world = FakeADBWorld(scenario: environment.scenario)
        let runner = ScriptedProcessRunner(world: world, logURL: environment.logURL)
        let locator = FixedADBLocator(path: environment.scenario == .adbMissing ? nil : "/fake/adb")
        let service = ADBService(pathProvider: preferences, locator: locator,
                                 parser: DeviceListParser(), runner: runner)
        let localizer = Localizer(provider: preferences)
        let scheduler = RunLoopScheduler()
        let monitor = DeviceMonitor(service: service, discovery: service, discoverySettings: preferences,
                                    intervalProvider: preferences, scheduler: scheduler)
        let alerts = AppKitAlertPresenter(localizer: localizer)
        let wireless = WirelessCoordinator(controller: service,
                                           switcher: WirelessSwitcher(controller: service, scheduler: scheduler,
                                                                      retryDelay: 0.1),
                                           prompts: AppKitWirelessPrompter(localizer: localizer),
                                           qrPairer: WirelessQRPairer(discovery: service, controller: service,
                                                                      scheduler: scheduler, pollInterval: 0.2),
                                           qrWindow: AppKitPairingQRPresenter(localizer: localizer),
                                           alerts: alerts, monitor: monitor, localizer: localizer)
        let launchAtLogin = InMemoryLaunchAtLogin()
        let makePreferencesWindow: @MainActor () -> PreferencesWindowController = {
            PreferencesWindowController(preferences: preferences, locator: locator,
                                        launchAtLogin: launchAtLogin, localizer: localizer)
        }
        return AppCoordinator(monitor: monitor, service: service, alerts: alerts, wireless: wireless,
                              settings: service, localizer: localizer,
                              makeStatusBar: { StatusBarController(actionHandler: $0, localizer: localizer) },
                              makePreferencesWindow: makePreferencesWindow)
    }
}
#endif
