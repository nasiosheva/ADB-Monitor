//
//  Translations+Batak.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

extension Translations {
    /// Batak Toba (`bbc`). Istilah teknis memakai kata serapan bahasa Indonesia, seperti lazim dipakai penutur.
    ///
    /// DRAF: ditulis oleh model AI dengan pengetahuan terbatas tentang bahasa Batak Toba dan belum ditinjau
    /// penutur asli. Kalimat yang tidak yakin sengaja memakai kata Indonesia. Wajib ditinjau sebelum dianggap final.
    static let batak: [L10nKey: String] = [
        .menuChecking: "Mangalului alat…",
        .menuNoDevices: "Ndang adong alat na marsambung",
        .menuDevicesHeader: "Alat Android (%@)",
        .menuAdbCustomMissing: "ADB ndang dapot di path na dipillit:",
        .menuAdbFixInPreferences: "Paturehon di Pengaturan.",
        .menuAdbNotInstalled: "ADB ndang dope dipasang",
        .menuAdbInstallHint: "Pasang i (brew install android-platform-tools)",
        .menuAdbSetPathHint: "manang paturehon path na di Pengaturan.",
        .menuAdbError: "Adong sala ni ADB",

        .detailStatus: "Status",
        .detailSerial: "Serial",
        .detailConnection: "Sambungan",
        .detailModel: "Model",
        .detailProduct: "Produk",
        .detailDevice: "Alat",
        .detailTransportID: "Transport ID",
        .labelValue: "%1$@: %2$@",

        .menuCopySerial: "Salin Nomor Serial",
        .menuRefresh: "Pabaru",
        .menuPreferences: "Pengaturan…",
        .menuQuit: "Pasidung ADB Monitor",

        .stateConnected: "Marsambung",
        .stateOffline: "Offline",
        .stateUnauthorized: "Ndang Diizinkon",
        .stateNoPermissions: "Ndang Adong Izin",
        .stateAuthorizing: "Mangizinkon",
        .stateConnecting: "Sai Marsambung",
        .stateRecovery: "Recovery",
        .stateSideload: "Sideload",
        .stateBootloader: "Bootloader",

        .hintUnauthorized: "Pillit \"Allow USB debugging\" di alat i.",
        .hintNoPermissions: "Sapata izin USB / aturan udev.",
        .hintOffline: "Sambung muse alat i manang pamulai muse server adb.",

        .connectionUSB: "USB",
        .connectionWiFi: "Wi-Fi",
        .connectionEmulator: "Emulator",
        .connectionUnknown: "Ndang diboto",

        .powerRestartMenu: "Pamulai Muse Alat…",
        .powerShutdownMenu: "Pamate Alat…",
        .powerRestartVerb: "Pamulai Muse",
        .powerShutdownVerb: "Pamate",
        .powerRestartConfirmTitle: "Pamulai muse %@?",
        .powerShutdownConfirmTitle: "Pamate %@?",
        .powerRestartConfirmBody: "Alat (%@) pamulai muse sannari. Data na so tarsimpan di alat i boi mago.",
        .powerShutdownConfirmBody: "Alat (%@) mate sannari, jala ndang boi pamulai sian Mac on. "
            + "Data na so tarsimpan di alat i boi mago.",
        .powerRestartFailureTitle: "Ndang boi pamulai muse %@",
        .powerShutdownFailureTitle: "Ndang boi pamate %@",

        .commonCancel: "Batal",

        .errorAdbNotFound: "ADB ndang dapot.",
        .errorTimedOut: "adb ndang mangalusi (timeout).",
        .errorLaunchFailed: "Ndang boi mamulai adb: %@",
        .errorLaunchAtLoginUnsupported: "Butuh macOS 13 atau yang lebih baru.",

        .prefsWindowTitle: "Pengaturan ADB Monitor",
        .prefsAdbPath: "Path ADB:",
        .prefsAdbPlaceholder: "Otomatis (tadinghon hosong)",
        .prefsChoose: "Pillit…",
        .prefsUsing: "Dipakke: %@",
        .prefsAdbNotFound: "ADB ndang dapot",
        .prefsNotExecutable: "Ndang file na boi dijalankon",
        .prefsRefreshInterval: "Tingki pabaru:",
        .prefsSeconds: "%@ detik",
        .prefsStartup: "Pamulaan:",
        .prefsLaunchAtLogin: "Buka tingki login",
        .prefsLaunchUnsupported: "Butuh macOS 13+. Pakke System Settings → Login Items.",
        .prefsLaunchApproval: "Setujui di System Settings → General → Login Items.",
        .prefsLanguage: "Hata:",
        .prefsLanguageSystem: "Sama dohot sistem",
        .prefsSave: "Simpan",
        .prefsSelectAdbPanel: "Pillit file adb",
    ]
}
