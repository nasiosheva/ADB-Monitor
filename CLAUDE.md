# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Ringkasan

ADB Monitor adalah aplikasi macOS menu bar (AppKit murni, tanpa SwiftUI, tanpa ikon Dock) yang memantau device Android lewat `adb devices -l`. Bundle ID `com.mories.adb.ADBMonitor`. Bukan git repository; tidak ada README/aturan Cursor/Copilot. Belum ada test target.

## Perintah

Satu target dan satu scheme (`ADBMonitor`), konfigurasi `Debug`/`Release`.

```sh
xcodebuild -project ADBMonitor.xcodeproj -scheme ADBMonitor -configuration Debug -derivedDataPath "$TMPDIR/adbmon-dd" build
open -n "$TMPDIR/adbmon-dd/Build/Products/Debug/ADBMonitor.app"
```

Aplikasi tidak punya jendela utama; hasilnya terlihat di menu bar. Saat menghentikan instance uji, `pkill` berdasarkan path build tersebut agar instance yang dijalankan dari Xcode tidak ikut mati. Belum ada test target; lihat bagian Pengujian.

## Arsitektur

Prinsipnya SOLID dengan dependency injection manual: semua kolaborator didepankan sebagai protokol kecil, dan hanya `AppDelegate` (composition root, `makeCoordinator()`) yang mengenal tipe konkret. Saat menambah fitur, ikuti pola ini: buat protokol di file yang sama dengan implementasi utamanya, inject lewat `init`, jangan membuat singleton.

Alur data satu arah: `ProcessManager` → `ADBService` → `DeviceMonitor` → `AppCoordinator` → `StatusBarController`.

| Folder | Isi dan tanggung jawab |
|---|---|
| `App/` | `AppDelegate` (entry point `@main` + lifecycle + composition root), `AppCoordinator` (menghubungkan monitor, status bar, dan aksi pengguna; satu-satunya yang tahu urutan "konfirmasi → perform → refresh → tampilkan error"), `MainMenuBuilder` |
| `Models/` | Tipe nilai murni tanpa AppKit: `ADBDevice`, `ADBStatus`, `ADBError`, `PowerAction` |
| `Services/` | `ADBService` (fasad command ADB), `ADBLocator`, `DeviceListParser`, `DeviceMonitor` (polling), `Scheduler` |
| `Preferences/` | Protokol preferensi + `UserDefaultsPreferences` |
| `UI/` | Semua kode AppKit: `StatusBarController`, `StatusMenuBuilder`, `StatusButtonPresenter`, `AlertPresenter`, `PreferencesWindowController`, `DeviceStateStyle`, `NSMenuItem+Factory` |
| `Utils/` | `ProcessManager` (+ `ProcessSupport`), helper Foundation |

Abstraksi penting:
- `ProcessRunning`, `ADBLocating`, `DeviceListParsing`, `ADBServicing`, `DeviceMonitoring`, `Scheduling`, `AlertPresenting`, `StatusMenuActionHandling`.
- Preferensi dipecah per kebutuhan (ISP): `ADBPathProviding` (dipakai `ADBService`), `RefreshIntervalProviding` (dipakai `DeviceMonitor`), `PreferencesStoring` (dipakai jendela Preferences). Perubahan dikabarkan lewat `Notification.Name.preferencesDidChange`.
- `PowerAction` adalah `CaseIterable`: menu, dialog konfirmasi, argumen adb, dan ketersediaan per state semuanya diturunkan dari enum itu. Menambah aksi (mis. reboot recovery) = menambah satu case, tanpa mengubah `StatusMenuBuilder`/`AlertPresenter`.
- Model tidak boleh `import AppKit`; gaya tampilan state ada di `UI/DeviceStateStyle.swift`.

Perilaku yang tidak kasat mata dari kode:
- Entry point: `AppDelegate` ber-`@main` dengan `static func main()` **eksplisit** (membuat delegate, memasangnya, lalu `run()`). `@main` saja tidak cukup: ia hanya memanggil `NSApplicationMain` yang baru membuat delegate bila ada nib, dan proyek ini tanpa nib, sehingga app jalan tanpa ikon menu bar dan tanpa error. Jangan kembali ke `main.swift`: top-level code di sana nonisolated di Swift 5 mode sehingga tidak boleh memanggil init `@MainActor`.
- `DeviceMonitor` memakai penjadwalan **single-shot** yang dijadwalkan setelah poll selesai (bukan repeating) sehingga poll tidak pernah tumpang tindih. `RunLoopScheduler` memakai mode `.common` agar tetap jalan ketika menu terbuka. `refresh()` saat poll berjalan menyetel flag sehingga satu poll tambahan dijalankan segera setelahnya. `onStatusChange` hanya dipanggil jika `ADBStatus` berubah.
- `ADBLocator`: path kustom yang tidak valid mengembalikan `nil` (tanpa fallback ke deteksi otomatis) sehingga menu menampilkan "not found at custom path".
- `ProcessManager`: pipe dibaca lewat `readabilityHandler`; setelah proses keluar EOF ditunggu dengan satu batas bersama (1 detik) karena `adb` bisa meninggalkan daemon child yang masih memegang ujung pipe. Closure memakai referensi weak untuk `Process` dan collector agar tidak ada retain cycle. PATH diperluas dengan `/opt/homebrew/bin` dkk. karena app GUI tidak mewarisi PATH shell.
- `StatusMenuBuilder.populate` mengisi ulang `NSMenu` yang sama (bukan membuat baru) agar menu yang sedang terbuka tidak tertutup. `NSMenuItem.target` bersifat weak, jadi builder harus tetap dimiliki `StatusBarController`.
- Aksi daya: restart = `adb -s <serial> reboot`, shutdown = `adb -s <serial> shell reboot -p`. Selalu didahului dialog konfirmasi.
- Ikon: `Assets.xcassets/AppIcon.appiconset` (10 ukuran macOS) dan `MenuBarIcon.imageset` (template monokrom 14x16 pt, `template-rendering-intent: template`) dibuat dari satu glyph hitam transparan (`~/Downloads/file.png`); generatornya (Swift + CoreGraphics) tidak disimpan di repo, jadi ganti ikon dengan membuat ulang kedua set itu. `StatusButtonPresenter` memuat `MenuBarIcon` lewat `NSImage(named:)` dan jatuh ke SF Symbol `iphone` bila asset hilang; ikon peringatan tetap SF Symbol.
- Format output `adb` berbeda antarversi: path USB bisa `usb:1-1` atau `2-1`, dan state `no permissions` terdiri dari dua kata. `DeviceListParser` menangani keduanya serta hanya menerima key `product|model|device|transport_id|usb`.

## Pengujian

Belum ada test target di proyek. Semua kode di `Models/`, `Services/`, `Preferences/`, dan `Utils/` tidak bergantung pada AppKit, jadi bisa diuji tanpa Xcode: kompilasi bersama harness `main.swift` yang berisi fake untuk protokol di atas.

```sh
swiftc -swift-version 5 -o /tmp/harness harness/main.swift ADBMonitor/{Models,Services,Preferences,Utils}/*.swift && /tmp/harness
```

`DeviceMonitor` adalah `@MainActor`, jadi di harness bungkus pemakaiannya dengan `MainActor.assumeIsolated { ... }`.

## Lint dan pengecekan concurrency

SwiftLint tidak terpasang; `xcrun swift-format lint` ikut Xcode. Gaya proyek adalah indentasi 4 spasi, lebar 120, parameter multi-baris diratakan ala Xcode (jadi catatan `Indentation`/`AddLines` dari swift-format diabaikan, itu preferensi bukan cacat). Yang diperbaiki: `LineLength` dan `TrailingComma`.

Build normal tidak memunculkan warning concurrency. Cek dengan mode ketat sebelum mengubah kode lintas-thread, keduanya harus bersih:

```sh
cd ADBMonitor && SDK=$(xcrun --show-sdk-path)
swiftc -typecheck -parse-as-library -sdk $SDK -target arm64-apple-macos12.0 -swift-version 5 -strict-concurrency=complete App/*.swift Models/*.swift Services/*.swift Preferences/*.swift UI/*.swift Utils/*.swift
swiftc -typecheck -parse-as-library -sdk $SDK -target arm64-apple-macos12.0 -swift-version 6 App/*.swift Models/*.swift Services/*.swift Preferences/*.swift UI/*.swift Utils/*.swift
```

Aturan isolasi: semua kode UI, `DeviceMonitor`, `AppCoordinator`, dan protokol yang dipakainya adalah `@MainActor`. Kode lintas-thread (`ProcessManager`, `ProcessStreamCollector`) ditandai `@unchecked Sendable` dengan alasan di komentar, dan `UncheckedSendable` hanya dipakai di dua titik terdokumentasi (hop queue di `ProcessManager`, `Timer` main run loop di `RunLoopScheduler`). Jangan memakai `MainActor.assumeIsolated` di kode aplikasi: baru tersedia di macOS 14, sedangkan deployment target 12.

## Konfigurasi build yang perlu diperhatikan

- `ENABLE_APP_SANDBOX = NO`: sandbox akan memblokir spawn `adb`, jadi jangan diaktifkan kembali. Tidak ada file `.entitlements`.
- `INFOPLIST_KEY_LSUIElement = YES` (Info.plist digenerate, tidak ada file plist) menyembunyikan ikon Dock. `INFOPLIST_KEY_NSPrincipalClass = NSApplication` diset eksplisit.
- `MACOSX_DEPLOYMENT_TARGET = 12.0`. Target awal 11.0 tidak bisa dipakai karena Xcode 27 hanya mendukung 12.0–27.x; kode sendiri hanya memakai API macOS 11.
- `SWIFT_DEFAULT_ACTOR_ISOLATION` (MainActor) sengaja dihapus agar `ProcessManager` dan kode background tidak terisolasi ke main actor. `SWIFT_VERSION = 5.0`.
- Target memakai `PBXFileSystemSynchronizedRootGroup`: file Swift baru di folder `ADBMonitor/` otomatis masuk target tanpa mengedit `project.pbxproj`.
- Format output `adb` berbeda antarversi: path USB bisa `usb:1-1` atau `2-1` tanpa prefix, dan state `no permissions` terdiri dari dua kata. `parseDevices` menangani keduanya serta hanya menerima key `product|model|device|transport_id|usb`.
- Diagnostik SourceKit "Cannot find type ..." setelah menambah file baru biasanya hanya indeks yang basi; andalkan hasil `xcodebuild`.
