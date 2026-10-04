//
//  UITestEnvironment.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

#if DEBUG
import Foundation

/// `adb` scenario simulated when the app is launched by UI tests.
enum UITestScenario: String {
    /// USB (ready), USB (unauthorized), one Wi-Fi device, and mDNS services (connect and pairing).
    case devices
    case empty
    case adbMissing = "adb-missing"
    case adbError = "adb-error"
}

/// UI test mode configuration, read from launch arguments. Only exists in Debug builds.
///
/// With `-ui-testing` the app runs no real `adb` and does not touch the user's preferences:
/// every adb command is answered by `FakeADBWorld` and written to a log file so tests can check it.
///
/// Arguments: `-ui-testing`, `-ui-scenario <name>`, `-ui-language <code>`. Environment: `ADBMONITOR_UITEST_LOG`.
struct UITestEnvironment {
    let scenario: UITestScenario
    let language: AppLanguage
    let logURL: URL?
    let defaultsSuiteName: String

    static func current(arguments: [String] = CommandLine.arguments,
                        environment: [String: String] = ProcessInfo.processInfo.environment) -> UITestEnvironment? {
        guard arguments.contains("-ui-testing") else { return nil }

        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
            return arguments[index + 1]
        }

        return UITestEnvironment(
            scenario: value(after: "-ui-scenario").flatMap(UITestScenario.init(rawValue:)) ?? .devices,
            language: value(after: "-ui-language").flatMap(AppLanguage.init(rawValue:)) ?? .english,
            logURL: environment["ADBMONITOR_UITEST_LOG"].map { URL(fileURLWithPath: $0) },
            defaultsSuiteName: "com.mories.adb.ADBMonitor.uitest")
    }
}
#endif
