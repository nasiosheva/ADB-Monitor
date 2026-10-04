//
//  ADBService.swift
//  ADBMonitor
//

import Foundation

protocol ADBServicing {
    /// `completion` dipanggil di thread yang sama dengan `ProcessRunning` (main untuk implementasi default).
    func listDevices(completion: @escaping (Result<[ADBDevice], ADBError>) -> Void)
    func perform(_ action: PowerAction, on serial: String, completion: @escaping (Result<Void, ADBError>) -> Void)
}

/// Fasad command ADB: menentukan lokasi binary, menjalankan command, lalu menerjemahkan hasilnya
/// ke model domain. Tidak tahu apa pun soal polling maupun UI.
final class ADBService: ADBServicing {

    private typealias RawResult = Result<ProcessOutput, ProcessError>
    private typealias CommandResult = Result<ProcessOutput, ADBError>

    private static let listTimeout: TimeInterval = 10
    private static let powerTimeout: TimeInterval = 15

    private let pathProvider: ADBPathProviding
    private let locator: ADBLocating
    private let parser: DeviceListParsing
    private let runner: ProcessRunning

    init(pathProvider: ADBPathProviding,
         locator: ADBLocating,
         parser: DeviceListParsing,
         runner: ProcessRunning) {
        self.pathProvider = pathProvider
        self.locator = locator
        self.parser = parser
        self.runner = runner
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

    private func execute(_ arguments: [String],
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

    private static func interpret(_ result: RawResult, customPath: String?) -> CommandResult {
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

    private static func failureMessage(from output: ProcessOutput) -> String {
        let firstLine = output.stderr
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmed }
            .first { !$0.isEmpty }
        return firstLine ?? "adb exited with code \(output.exitCode)."
    }
}
