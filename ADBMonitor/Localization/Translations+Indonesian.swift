//
//  Translations+Indonesian.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

extension Translations {
    static let indonesian: [L10nKey: String] = [
        .menuChecking: "Memeriksa perangkat…",
        .menuNoDevices: "Tidak ada perangkat terhubung",
        .menuDevicesHeader: "Perangkat Android (%@)",
        .menuAdbCustomMissing: "ADB tidak ditemukan di path kustom:",
        .menuAdbFixInPreferences: "Perbaiki di Preferensi.",
        .menuAdbNotInstalled: "ADB belum terpasang",
        .menuAdbInstallHint: "Pasang (brew install android-platform-tools)",
        .menuAdbSetPathHint: "atau atur path-nya di Preferensi.",
        .menuAdbError: "Error ADB",

        .detailStatus: "Status",
        .detailSerial: "Serial",
        .detailConnection: "Koneksi",
        .detailModel: "Model",
        .detailProduct: "Produk",
        .detailDevice: "Perangkat",
        .detailTransportID: "Transport ID",
        .labelValue: "%1$@: %2$@",

        .menuCopySerial: "Salin Nomor Serial",
        .menuRefresh: "Segarkan",
        .menuPreferences: "Preferensi…",
        .menuQuit: "Keluar dari ADB Monitor",

        .stateConnected: "Terhubung",
        .stateOffline: "Offline",
        .stateUnauthorized: "Belum Diotorisasi",
        .stateNoPermissions: "Tanpa Izin",
        .stateAuthorizing: "Mengotorisasi",
        .stateConnecting: "Menghubungkan",
        .stateRecovery: "Recovery",
        .stateSideload: "Sideload",
        .stateBootloader: "Bootloader",

        .hintUnauthorized: "Setujui permintaan USB debugging di perangkat.",
        .hintNoPermissions: "Periksa izin USB / aturan udev.",
        .hintOffline: "Hubungkan ulang perangkat atau restart server adb.",

        .connectionUSB: "USB",
        .connectionWiFi: "Wi-Fi",
        .connectionEmulator: "Emulator",
        .connectionUnknown: "Tidak diketahui",

        .powerRestartMenu: "Restart Perangkat…",
        .powerShutdownMenu: "Matikan Perangkat…",
        .powerRestartVerb: "Restart",
        .powerShutdownVerb: "Matikan",
        .powerRestartConfirmTitle: "Restart %@?",
        .powerShutdownConfirmTitle: "Matikan %@?",
        .powerRestartConfirmBody: "Perangkat (%@) akan langsung restart. Pekerjaan yang belum disimpan di perangkat "
            + "bisa hilang.",
        .powerShutdownConfirmBody: "Perangkat (%@) akan langsung mati dan tidak bisa dinyalakan lagi dari Mac ini. "
            + "Pekerjaan yang belum disimpan di perangkat bisa hilang.",
        .powerRestartFailureTitle: "Gagal me-restart %@",
        .powerShutdownFailureTitle: "Gagal mematikan %@",

        .commonCancel: "Batal",

        .errorAdbNotFound: "ADB tidak ditemukan.",
        .errorTimedOut: "adb tidak merespons (waktu habis).",
        .errorLaunchFailed: "Gagal menjalankan adb: %@",
        .errorLaunchAtLoginUnsupported: "Buka saat login memerlukan macOS 13 atau lebih baru.",

        .prefsWindowTitle: "Preferensi ADB Monitor",
        .prefsAdbPath: "Path ADB:",
        .prefsAdbPlaceholder: "Deteksi otomatis (kosongkan)",
        .prefsChoose: "Pilih…",
        .prefsUsing: "Memakai: %@",
        .prefsAdbNotFound: "ADB tidak ditemukan",
        .prefsNotExecutable: "Bukan file yang bisa dijalankan",
        .prefsRefreshInterval: "Interval penyegaran:",
        .prefsSeconds: "%@ dtk",
        .prefsStartup: "Saat mulai:",
        .prefsLaunchAtLogin: "Buka saat login",
        .prefsLaunchUnsupported: "Perlu macOS 13+. Gunakan Pengaturan Sistem → Item Login.",
        .prefsLaunchApproval: "Setujui di Pengaturan Sistem → Umum → Item Login.",
        .prefsLanguage: "Bahasa:",
        .prefsLanguageSystem: "Ikuti sistem",
        .prefsSave: "Simpan",
        .prefsSelectAdbPanel: "Pilih file eksekusi adb",
    ]
}
