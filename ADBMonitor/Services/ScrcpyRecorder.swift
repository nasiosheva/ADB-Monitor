//
//  ScrcpyRecorder.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// Records the screen of a device into an MP4 file on the Mac.
@MainActor
protocol ScreenRecording: AnyObject {
    func isRecording(serial: String) -> Bool

    /// Starts recording into `destination`. `completion` is called once, when the recording has ended (stopped,
    /// time limit reached, or failed), or right away when it could not start. A device that is already recording
    /// is left alone and `completion` is not called for the second request.
    func start(serial: String, to destination: URL, completion: @escaping (Result<Void, ADBError>) -> Void)

    /// Asks the recording to finish; the file is closed properly and `completion` of `start` is called.
    func stop(serial: String)
}

/// What is recorded. The defaults are small and play everywhere: H.264 in MP4, no audio.
struct ScreenRecordingProfile: Equatable {
    /// Longest side in pixels. 854 is "480p" for a phone held upright (480 × 854), and the aspect ratio is kept.
    var maxSize = 854
    var bitRate = "1M"
    var framesPerSecond = 24
    /// Seconds. `scrcpy` stops by itself and closes the file.
    var timeLimit = 300

    /// No window and no audio on the Mac: `scrcpy` only writes the stream to the file.
    func arguments(serial: String, destination: URL) -> [String] {
        ["-s", serial,
         "--record=\(destination.path)", "--record-format=mp4",
         "--max-size=\(maxSize)", "--video-bit-rate=\(bitRate)", "--max-fps=\(framesPerSecond)",
         "--time-limit=\(timeLimit)",
         "--no-audio", "--no-playback"]
    }
}

/// Records with `scrcpy --record`. Stopping sends it SIGINT (like Ctrl+C), which lets `scrcpy` finish the file;
/// if it has not exited after `stopGrace` seconds it gets SIGTERM.
@MainActor
final class ScrcpyRecorder: ScreenRecording {

    private struct Session {
        let process: RunningProcess
        let completion: (Result<Void, ADBError>) -> Void
        var stopRequested = false
        var forceStop: ScheduledTask?
    }

    private let resolver: ScrcpyResolver
    private let profile: ScreenRecordingProfile
    private let launcher: ProcessLaunching
    private let scheduler: Scheduling
    private let stopGrace: TimeInterval
    private var sessions: [String: Session] = [:]

    init(scrcpyLocator: ADBLocating,
         adbLocator: ADBLocating,
         pathProvider: ADBPathProviding,
         profile: ScreenRecordingProfile = ScreenRecordingProfile(),
         launcher: ProcessLaunching,
         scheduler: Scheduling,
         stopGrace: TimeInterval = 5) {
        self.resolver = ScrcpyResolver(scrcpyLocator: scrcpyLocator, adbLocator: adbLocator,
                                       pathProvider: pathProvider)
        self.profile = profile
        self.launcher = launcher
        self.scheduler = scheduler
        self.stopGrace = stopGrace
    }

    func isRecording(serial: String) -> Bool {
        sessions[serial] != nil
    }

    func start(serial: String, to destination: URL, completion: @escaping (Result<Void, ADBError>) -> Void) {
        guard !serial.trimmed.isEmpty else {
            completion(.failure(.commandFailed("Missing serial number.")))
            return
        }
        guard sessions[serial] == nil else { return }

        let tool: ScrcpyResolver.Tool
        switch resolver.resolve() {
        case .success(let resolved): tool = resolved
        case .failure(let error):
            completion(.failure(error))
            return
        }

        do {
            let process = try launcher.launch(executable: tool.executable,
                                              arguments: profile.arguments(serial: serial, destination: destination),
                                              environment: tool.environment) { [weak self] exitCode, errorOutput in
                self?.didExit(serial: serial, exitCode: exitCode, errorOutput: errorOutput)
            }
            sessions[serial] = Session(process: process, completion: completion)
        } catch {
            completion(.failure(ScrcpyResolver.error(forLaunchFailure: error)))
        }
    }

    func stop(serial: String) {
        guard var session = sessions[serial], !session.stopRequested else { return }
        session.stopRequested = true
        session.process.interrupt()
        session.forceStop = scheduler.schedule(after: stopGrace) { [weak self] in
            self?.sessions[serial]?.process.terminate()
        }
        sessions[serial] = session
    }

    /// An exit after a stop request is a success whatever its code: the user asked for it.
    private func didExit(serial: String, exitCode: Int32, errorOutput: String) {
        guard let session = sessions.removeValue(forKey: serial) else { return }
        session.forceStop?.cancel()
        if exitCode == 0 || session.stopRequested {
            session.completion(.success(()))
        } else {
            session.completion(.failure(ScrcpyMirror.failure(exitCode, errorOutput)))
        }
    }
}
