# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

ADB Monitor is a macOS menu bar app (pure AppKit, no SwiftUI, no Dock icon) that polls `adb devices -l` and shows connected Android devices, with restart and shut down actions. Bundle ID: `com.mories.adb.ADBMonitor`. Deployment target: macOS 12.0. About 1.6k lines of Swift, no third-party dependencies.

`README.md` is the user-facing documentation and is written in Indonesian. This file is the engineering reference.

There are no Cursor, Copilot, or other agent rule files in the repo. There is no test target and no linter configuration.

## Commands

One target and one scheme (`ADBMonitor`), configurations `Debug` and `Release`.

```sh
xcodebuild -project ADBMonitor.xcodeproj -scheme ADBMonitor -configuration Debug -derivedDataPath "$TMPDIR/adbmon-dd" build
open -n "$TMPDIR/adbmon-dd/Build/Products/Debug/ADBMonitor.app"
```

The app has no main window. Its output is the menu bar item.

**Stopping a test instance:** record the PID of the instance you launched and `kill` that PID. Do not use `pkill -f` with a path pattern. The copy that Xcode runs from DerivedData has the same executable name, and a loose pattern kills it too.

## Architecture

The design follows SOLID with manual dependency injection. Collaborators are small protocols. `AppDelegate.makeCoordinator()` is the composition root and the only place that names concrete types. When adding a feature, follow the same pattern: declare the protocol in the same file as its main implementation, inject it through `init`, and do not add singletons.

Data flows one way: `ProcessManager` → `ADBService` → `DeviceMonitor` → `AppCoordinator` → `StatusBarController`. User actions flow back through `StatusMenuActionHandling` to `AppCoordinator`.

| Folder | Contents |
|---|---|
| `App/` | `AppDelegate` (`@main` entry point, lifecycle, composition root), `AppCoordinator` (wires monitor, status bar, and user actions; owns the sequence confirm → perform → refresh → show error), `MainMenuBuilder` |
| `Models/` | Plain value types, no AppKit: `ADBDevice`, `ADBStatus`, `ADBError`, `PowerAction` |
| `Services/` | `ADBService` (ADB command facade), `ADBLocator`, `DeviceListParser`, `DeviceMonitor` (polling), `Scheduler` |
| `Preferences/` | Preference protocols and `UserDefaultsPreferences` |
| `UI/` | All AppKit code: `StatusBarController`, `StatusMenuBuilder`, `StatusButtonPresenter`, `AlertPresenter`, `PreferencesWindowController`, `DeviceStateStyle`, `NSMenuItem+Factory` |
| `Utils/` | `ProcessManager` and `ProcessSupport`, `UncheckedSendable`, Foundation helpers |

Key abstractions:
- `ProcessRunning`, `ADBLocating`, `DeviceListParsing`, `ADBServicing`, `DeviceMonitoring`, `Scheduling`, `AlertPresenting`, `StatusMenuActionHandling`.
- Preferences are split by consumer (interface segregation): `ADBPathProviding` (used by `ADBService`), `RefreshIntervalProviding` (used by `DeviceMonitor`), `PreferencesStoring` (used by the Preferences window). Changes are broadcast with `Notification.Name.preferencesDidChange`.
- `PowerAction` is `CaseIterable`. The menu items, the confirmation dialog, the adb arguments, and per-state availability are all derived from it. Adding an action (for example reboot to recovery) means adding one case. `StatusMenuBuilder` and `AlertPresenter` do not change.
- Models must not `import AppKit`. State styling lives in `UI/DeviceStateStyle.swift`.

Behavior that is not obvious from reading the code:

- **Entry point.** `AppDelegate` is `@main` and defines an explicit `static func main()` that creates the delegate, assigns it, and calls `run()`. `@main` alone is not enough: it only calls `NSApplicationMain`, which creates the delegate only when a nib exists. This project has no nib, so the app would run with no menu bar item and no error. Do not go back to `main.swift`: top-level code there is nonisolated in Swift 5 mode and cannot call `@MainActor` initializers.
- **Polling.** `DeviceMonitor` schedules the next poll after the current one finishes, with a single-shot timer, so polls never overlap. `RunLoopScheduler` registers the timer in `.common` run loop mode so polling continues while the menu is open. A `refresh()` during an active poll sets a flag, and one more poll runs right after. `onStatusChange` fires only when `ADBStatus` actually changed.
- **Custom ADB path.** If the user sets a custom path and it is invalid, `ADBLocator` returns `nil`. It does not fall back to auto-detection. The menu then shows "ADB not found at custom path".
- **Process I/O.** `ProcessManager` reads pipes through `readabilityHandler`. After the process exits it waits for EOF with one shared 1-second deadline for stdout and stderr, because `adb` can leave a daemon child that still holds the pipe's write end. Closures hold `Process` and the stream collectors weakly to avoid retain cycles. `PATH` is extended with `/opt/homebrew/bin` and similar directories because GUI apps do not inherit the shell `PATH`.
- **Menu rebuilds.** `StatusMenuBuilder.populate` refills the same `NSMenu` instead of creating a new one, so an open menu does not close. `NSMenuItem.target` is weak, so `StatusBarController` must keep ownership of the builder.
- **Power actions.** Restart runs `adb -s <serial> reboot`. Shut down runs `adb -s <serial> shell reboot -p`. Both are always preceded by a confirmation dialog. Restart is available for Connected and Recovery devices, shut down only for Connected.
- **adb output formats.** The output of `adb devices -l` differs between adb versions. The USB path can be `usb:1-1` or a bare `2-1`, and the state `no permissions` is two words. `DeviceListParser` handles both, ignores daemon lines that start with `*`, and accepts only the keys `product`, `model`, `device`, `transport_id`, and `usb`.
- **Icons.** `Assets.xcassets/AppIcon.appiconset` (10 macOS sizes) and `MenuBarIcon.imageset` (monochrome template, 14x16 pt, `template-rendering-intent: template`) were generated from a single black, transparent glyph. The generator script (Swift and CoreGraphics) is not in the repo, so changing the icon means regenerating both sets. `StatusButtonPresenter` loads `MenuBarIcon` with `NSImage(named:)` and falls back to the SF Symbol `iphone` if the asset is missing. The warning icon is always an SF Symbol.

## Testing

There is no test target. Everything in `Models/`, `Services/`, `Preferences/`, and `Utils/` is free of AppKit, so it can be tested without Xcode by compiling it together with a small `main.swift` harness that supplies fakes for the protocols above. The harness is not committed.

```sh
swiftc -swift-version 5 -o /tmp/harness harness/main.swift ADBMonitor/{Models,Services,Preferences,Utils}/*.swift && /tmp/harness
```

`DeviceMonitor` is `@MainActor`. In the harness, wrap its use in `MainActor.assumeIsolated { ... }`.

## Lint and concurrency checks

SwiftLint is not installed. `xcrun swift-format lint` ships with Xcode and can be used. Project style: 4-space indentation, 120-column limit, multi-line parameter lists aligned Xcode-style. Ignore the `Indentation` and `AddLines` findings from swift-format; they are a style preference, not defects. `LineLength` and `TrailingComma` findings should be fixed.

A normal build shows no concurrency warnings. Before changing cross-thread code, run both strict checks. Both must be clean:

```sh
cd ADBMonitor && SDK=$(xcrun --show-sdk-path)
swiftc -typecheck -parse-as-library -sdk $SDK -target arm64-apple-macos12.0 -swift-version 5 -strict-concurrency=complete App/*.swift Models/*.swift Services/*.swift Preferences/*.swift UI/*.swift Utils/*.swift
swiftc -typecheck -parse-as-library -sdk $SDK -target arm64-apple-macos12.0 -swift-version 6 App/*.swift Models/*.swift Services/*.swift Preferences/*.swift UI/*.swift Utils/*.swift
```

Isolation rules:
- All UI code, `DeviceMonitor`, `AppCoordinator`, and the protocols they use are `@MainActor`.
- Cross-thread code (`ProcessManager`, `ProcessStreamCollector`) is `@unchecked Sendable`, with the reason in a comment.
- `UncheckedSendable` is used in exactly two documented places: the queue hop in `ProcessManager` and the main-run-loop `Timer` in `RunLoopScheduler`.
- Do not use `MainActor.assumeIsolated` in app code. It requires macOS 14 and the deployment target is 12.

## Conventions

- **File header.** Every `.swift` file starts with this 6-line header, and new files must use it:

  ```swift
  //
  //  FileName.swift
  //  ADBMonitor
  //
  //  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
  //
  ```

  The name string is written exactly as shown, with no space after the commas, as requested by the repo owner.

## Git

- Remote: `origin` → `https://github.com/nasiosheva/ADB-Monitor.git`. The repository is **public**.
- Work on the `development` branch. Do not create or push `main`. `development` is the default branch on GitHub.
- Commit identity is set in the local repo config: `nasiosheva <deomories@gmail.com>`. It differs from the global identity on this machine, so do not change it or commit with `-c user.*` overrides. The local credential helper is `gh auth git-credential`, which authenticates as `nasiosheva`.
- Do not add `Co-Authored-By: Claude` trailers or any Claude/Anthropic attribution to commits or PR descriptions. The owner asked for this explicitly, and it overrides the default attribution behavior of Claude Code.
- Commit and push only when asked. Use `--force-with-lease` for any force push, and only on an explicit request.

## Build configuration

- `ENABLE_APP_SANDBOX = NO`. The sandbox blocks spawning `adb`, so do not turn it back on. There is no `.entitlements` file. As a consequence the app cannot ship through the Mac App Store.
- `INFOPLIST_KEY_LSUIElement = YES` hides the Dock icon. The Info.plist is generated, so there is no plist file in the repo. `INFOPLIST_KEY_NSPrincipalClass = NSApplication` is set explicitly.
- `MACOSX_DEPLOYMENT_TARGET = 12.0`. The original target of 11.0 is not possible because Xcode 27 supports 12.0 through 27.x only. The code itself uses only macOS 11 APIs.
- `SWIFT_VERSION = 5.0`. `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` was removed on purpose so that `ProcessManager` and other background code are not isolated to the main actor.
- The target uses `PBXFileSystemSynchronizedRootGroup`. New Swift files placed under `ADBMonitor/` join the target automatically, without editing `project.pbxproj`.
- Code signing is "Sign to Run Locally" (ad hoc). The app is not notarized.
- SourceKit often reports "Cannot find type ..." right after files are added. That is usually a stale index. Trust the `xcodebuild` result.
