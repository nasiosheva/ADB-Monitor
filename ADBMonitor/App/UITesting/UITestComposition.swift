//
//  UITestComposition.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

#if DEBUG
import AppKit

/// Appends one line per command to the log file that UI tests read.
struct CommandLog {
    let url: URL?

    /// Starts from an empty log on every launch.
    init(url: URL?) {
        self.url = url
        if let url = url { try? Data().write(to: url) }
    }

    func record(_ line: String) {
        guard let url = url, let data = (line + "\n").data(using: .utf8),
              let handle = try? FileHandle(forWritingTo: url) else { return }
        handle.seekToEndOfFile()
        handle.write(data)
        try? handle.close()
    }
}

/// A `ProcessRunning` that runs no process: answers come from `FakeADBWorld`,
/// and every command is recorded (one line per command) so UI tests can check what was sent.
final class ScriptedProcessRunner: ProcessRunning {

    private let world: FakeADBWorld
    private let log: CommandLog

    init(world: FakeADBWorld, log: CommandLog) {
        self.world = world
        self.log = log
    }

    func run(executable: String,
             arguments: [String],
             timeout: TimeInterval,
             completion: @escaping (Result<ProcessOutput, ProcessError>) -> Void) {
        let isFastboot = executable.hasSuffix("fastboot")
        log.record((isFastboot ? "fastboot " : "adb ") + arguments.joined(separator: " "))
        let output = isFastboot ? world.runFastboot(arguments) : world.run(arguments)
        let result = ProcessOutput(stdout: output.stdout, stderr: output.stderr, exitCode: output.exitCode)
        // Asynchronous like `ProcessManager`, which delivers results on the main queue.
        DispatchQueue.main.async { completion(.success(result)) }
    }
}

/// Records the `scrcpy` command instead of starting it. The fake process stays "running" until it is interrupted
/// (which is how a recording is stopped) or terminated; a mirror window stays open until the app quits.
@MainActor
final class LoggingProcessLauncher: ProcessLaunching {

    @MainActor
    private final class FakeProcess: RunningProcess {
        private var onExit: (@MainActor @Sendable (Int32, String) -> Void)?

        init(onExit: @escaping @MainActor @Sendable (Int32, String) -> Void) { self.onExit = onExit }

        func interrupt() { finish() }
        func terminate() { finish() }

        private func finish() {
            guard let onExit = onExit else { return }
            self.onExit = nil
            onExit(0, "")
        }
    }

    private let log: CommandLog

    init(log: CommandLog) { self.log = log }

    func launch(executable: String,
                arguments: [String],
                environment: [String: String],
                onExit: @escaping @MainActor @Sendable (Int32, String) -> Void) throws -> RunningProcess {
        log.record("scrcpy " + arguments.joined(separator: " "))
        return FakeProcess(onExit: onExit)
    }
}

/// Does nothing: UI tests must not open Finder windows or ask for notification permission.
@MainActor
final class SilentSystemEffects: FileRevealing, DeviceNotifying {
    func reveal(_ url: URL) {}
    func prepare() {}
    func notify(_ change: DeviceChange) {}
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
                         wirelessDiscovery: true, deviceNotifications: false)

        let world = FakeADBWorld(scenario: environment.scenario)
        let log = CommandLog(url: environment.logURL)
        let runner = ScriptedProcessRunner(world: world, log: log)
        let locator = FixedADBLocator(path: environment.scenario == .adbMissing ? nil : "/fake/adb")
        let service = ADBService(pathProvider: preferences, locator: locator,
                                 parser: DeviceListParser(), runner: runner)
        let fastboot = FastbootService(locator: FixedADBLocator(path: "/fake/fastboot"), runner: runner)
        let localizer = Localizer(provider: preferences)
        let scheduler = RunLoopScheduler()
        let monitor = DeviceMonitor(service: service, discovery: service, fastboot: fastboot,
                                    discoverySettings: preferences, intervalProvider: preferences,
                                    scheduler: scheduler)
        let alerts = AppKitAlertPresenter(localizer: localizer)
        let wireless = WirelessCoordinator(controller: service,
                                           switcher: WirelessSwitcher(controller: service, scheduler: scheduler,
                                                                      retryDelay: 0.1),
                                           prompts: AppKitWirelessPrompter(localizer: localizer),
                                           qrPairer: WirelessQRPairer(discovery: service, controller: service,
                                                                      scheduler: scheduler, pollInterval: 0.2),
                                           qrWindow: AppKitPairingQRPresenter(localizer: localizer),
                                           alerts: alerts, monitor: monitor, localizer: localizer)
        let tools = ToolsCoordinator(server: service, fastboot: fastboot, alerts: alerts, monitor: monitor,
                                     localizer: localizer)
        let effects = SilentSystemEffects()
        let scrcpyLocator = FixedADBLocator(path: "/fake/scrcpy")
        let launcher = LoggingProcessLauncher(log: log)
        let screen = ScreenCoordinator(screenshots: service,
                                       recorder: ScrcpyRecorder(scrcpyLocator: scrcpyLocator, adbLocator: locator,
                                                                pathProvider: preferences, launcher: launcher,
                                                                scheduler: scheduler),
                                       mirror: ScrcpyMirror(scrcpyLocator: scrcpyLocator, adbLocator: locator,
                                                            pathProvider: preferences, launcher: launcher,
                                                            scheduler: scheduler),
                                       files: effects, alerts: alerts, localizer: localizer,
                                       directory: FileManager.default.temporaryDirectory)
        let changeNotifier = DeviceChangeNotifier(settings: preferences, notifier: effects)
        let launchAtLogin = InMemoryLaunchAtLogin()
        let makePreferencesWindow: @MainActor () -> PreferencesWindowController = {
            PreferencesWindowController(preferences: preferences, locator: locator,
                                        launchAtLogin: launchAtLogin, localizer: localizer)
        }
        return AppCoordinator(monitor: monitor, service: service, alerts: alerts, wireless: wireless,
                              tools: tools, screen: screen, settings: service, localizer: localizer,
                              detailsTracker: DeviceDetailsTracker(reader: service, refreshInterval: 5),
                              changeTracker: changeNotifier,
                              makeStatusBar: { StatusBarController(actionHandler: $0, localizer: localizer) },
                              makePreferencesWindow: makePreferencesWindow)
    }
}
#endif
