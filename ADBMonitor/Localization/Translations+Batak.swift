//
//  Translations+Batak.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

extension Translations {
    /// Batak Toba (`bbc`). Technical terms use Indonesian loanwords, as speakers commonly do.
    ///
    /// DRAFT: written by an AI model with limited knowledge of Batak Toba and not yet reviewed by a
    /// native speaker. Sentences I was unsure about deliberately use Indonesian words. Review before treating as final.
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
        .menuOpenDeveloperOptions: "Buka Opsi Pengembang",
        .developerOptionsFailureTitle: "Ndang boi buka Opsi pengembang di %@",
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

        .menuWirelessHeader: "Na dapot lewat Wi-Fi (%@)",
        .menuWirelessConnectItem: "Sambung tu %@",
        .menuWirelessPairItem: "Pairing dohot %@…",
        .menuConnectByAddress: "Sambung tu Alamat IP…",
        .menuPairDevice: "Pairing Alat…",
        .menuPairWithQR: "Pairing dohot Kode QR…",
        .menuDisconnect: "Putus Sambungan",
        .menuSwitchToWiFi: "Pindah tu Wi-Fi",

        .connectPromptTitle: "Sambung lewat Wi-Fi",
        .connectPromptBody: "Isi alamat IP ni alat. Port biasa 5555; molo Wireless debugging, pakke port na tarida "
            + "di alat i.",
        .connectPromptPlaceholder: "192.168.1.5:5555",
        .connectPromptButton: "Sambung",
        .pairPromptTitle: "Pairing alat",
        .pairPromptBody: "Di alat i buka Opsi pengembang → Wireless debugging → Pair device with pairing code, "
            + "laos isi alamat dohot kode na adong disi.",
        .pairAddressPlaceholder: "Alamat IP dohot port (192.168.1.5:41223)",
        .pairCodePlaceholder: "Kode pairing 6 angka",
        .pairPromptButton: "Pairing",

        .qrPromptTitle: "Pairing dohot kode QR",
        .qrPromptBody: "Di HP i buka Opsi pengembang → Wireless debugging → Pair device with QR code, laos pindai "
            + "kode on. HP i dohot Mac on masa di jaringan Wi-Fi na sama.",
        .qrStatusWaiting: "Manontong HP mamindai kode i…",
        .qrStatusPairing: "Kode nunga dipindai. Pairing…",
        .qrFailureTitle: "Ndang boi pairing dohot kode QR",
        .errorQRTimedOut: "Ndang adong HP na mamindai kode i satorop waktu. Pastikan HP i dohot Mac on di jaringan "
            + "Wi-Fi na sama jala jaringan i ndang manghalangi mDNS, laos cobai muse.",

        .pairSuccessTitle: "Pairing marhasil",
        .pairSuccessBody: "%@ nunga dipairing. Molo ndang tarida di daftar, sambung sian Na dapot lewat Wi-Fi.",
        .wirelessConnectFailureTitle: "Ndang boi sambung tu %@",
        .wirelessPairFailureTitle: "Ndang boi pairing dohot %@",
        .wirelessDisconnectFailureTitle: "Ndang boi putus sambungan %@",
        .wirelessSwitchFailureTitle: "Ndang boi pindahon %@ tu Wi-Fi",
        .errorNoWiFiAddress: "Alat on ndang adong alamat IP Wi-Fi. Sambung dolo tu Wi-Fi.",
        .errorInvalidAddress: "Isi alamat IP na tama, boi dihut port (songon 192.168.1.5:5555).",
        .errorInvalidPairingCode: "Isi kode pairing 6 angka na tarida di alat i.",
        .errorNoRouteHint: "Molo alat na asing di jaringan on boi dijangkau, server adb na nunga mansai mungkin "
            + "ndang adong izin Jaringan Lokal. Jalankon adb kill-server, laos izinkon ADB Monitor di "
            + "Pengaturan Sistem → Privasi & Keamanan → Jaringan Lokal.",

        .prefsWireless: "Wi-Fi:",
        .prefsWirelessDiscovery: "Deteksi alat di Wi-Fi",
        .prefsWirelessNote: "Memakai mDNS; sebagian jaringan memblokirnya.",
    ]
}
