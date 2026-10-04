//
//  ADBService.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

protocol ADBServicing {
    /// `completion` is called on the same thread as `ProcessRunning` (main for the default implementation).
    func listDevices(completion: @escaping (Result<[ADBDevice], ADBError>) -> Void)
    func perform(_ action: PowerAction, on serial: String, completion: @escaping (Result<Void, ADBError>) -> Void)
}

/// ADB command facade: locates the binary, runs the command, then translates the result
/// into domain models. Knows nothing about polling or UI.
final class ADBService: ADBServicing {

    typealias RawResult = Result<ProcessOutput, ProcessError>
    typealias CommandResult = Result<ProcessOutput, ADBError>

    private static let listTimeout: TimeInterval = 10
    private static let powerTimeout: TimeInterval = 15

    private let pathProvider: ADBPathProviding
    private let locator: ADBLocating
    private let parser: DeviceListParsing
    private let runner: ProcessRunning
    let serviceParser: WirelessServiceParsing
    let detailsParser: DeviceDetailsParsing

    init(pathProvider: ADBPathProviding,
         locator: ADBLocating,
         parser: DeviceListParsing,
         runner: ProcessRunning,
         serviceParser: WirelessServiceParsing = WirelessServiceParser(),
         detailsParser: DeviceDetailsParsing = DeviceDetailsParser()) {
        self.pathProvider = pathProvider
        self.locator = locator
        self.parser = parser
        self.runner = runner
        self.serviceParser = serviceParser
        self.detailsParser = detailsParser
    }

    func listDevices(completion: @escaping (Result<[ADBDevice], ADBError>) -> Void) {
        execute(["devices", "-l"], timeout: Self.listTimeout) { [parser] result in
            completion(result.map { parser.parse($0.stdout) })
        }
    }

    func perform(_ action: PowerAction, on serial: String, completion: @escaping (Result<Void, ADBError>) -> Void) {
        execute(["-s", serial] + action.adbArguments, timeout: Self.powerTimeout) { result in
            completion(result.map { _ in () })
        }
    }

    // MARK: - Execution

    func execute(_ arguments: [String],
                 timeout: TimeInterval,
                 completion: @escaping (CommandResult) -> Void) {
        let customPath = pathProvider.adbPath
        guard let adbPath = locator.locate(customPath: customPath) else {
            completion(.failure(.notFound(customPath: customPath)))
            return
        }

        runner.run(executable: adbPath, arguments: arguments, timeout: timeout) { result in
            completion(Self.interpret(result, customPath: customPath))
        }
    }

    static func interpret(_ result: RawResult, customPath: String?) -> CommandResult {
        switch result {
        case .success(let output) where output.exitCode == 0:
            return .success(output)
        case .success(let output):
            return .failure(.commandFailed(failureMessage(from: output)))
        case .failure(.executableNotFound):
            return .failure(.notFound(customPath: customPath))
        case .failure(.timedOut):
            return .failure(.timedOut)
        case .failure(.launchFailed(let reason)):
            return .failure(.launchFailed(reason))
        }
    }

    static func failureMessage(from output: ProcessOutput) -> String {
        firstLine(of: output.stderr) ?? "adb exited with code \(output.exitCode)."
    }

    /// First non-empty line, or `nil`.
    static func firstLine(of text: String) -> String? {
        text.split(whereSeparator: \.isNewline).map { $0.trimmed }.first { !$0.isEmpty }
    }
}
