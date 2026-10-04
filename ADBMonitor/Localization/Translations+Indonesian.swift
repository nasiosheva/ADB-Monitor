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
        .menuOpenDeveloperOptions: "Buka Opsi Pengembang",
        .developerOptionsFailureTitle: "Gagal membuka Opsi pengembang di %@",
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

        .menuWirelessHeader: "Tersedia lewat Wi-Fi (%@)",
        .menuWirelessConnectItem: "Hubungkan ke %@",
        .menuWirelessPairItem: "Pairing dengan %@…",
        .menuConnectByAddress: "Hubungkan ke Alamat IP…",
        .menuPairDevice: "Pairing Perangkat…",
        .menuPairWithQR: "Pairing dengan Kode QR…",
        .menuDisconnect: "Putuskan Koneksi",
        .menuSwitchToWiFi: "Pindah ke Wi-Fi",

        .connectPromptTitle: "Hubungkan lewat Wi-Fi",
        .connectPromptBody: "Masukkan alamat IP perangkat. Port bawaan 5555; untuk Wireless debugging pakai port "
            + "yang tampil di perangkat.",
        .connectPromptPlaceholder: "192.168.1.5:5555",
        .connectPromptButton: "Hubungkan",
        .pairPromptTitle: "Pairing perangkat",
        .pairPromptBody: "Di perangkat buka Opsi pengembang → Debugging nirkabel → Sambungkan perangkat dengan kode "
            + "pairing, lalu masukkan alamat dan kode yang tampil di sana.",
        .pairAddressPlaceholder: "Alamat IP dan port (192.168.1.5:41223)",
        .pairCodePlaceholder: "Kode pairing 6 digit",
        .pairPromptButton: "Pairing",

        .qrPromptTitle: "Pairing dengan kode QR",
        .qrPromptBody: "Di ponsel buka Opsi pengembang → Debugging nirkabel → Sambungkan perangkat dengan kode QR, "
            + "lalu pindai kode ini. Ponsel dan Mac ini harus berada di jaringan Wi-Fi yang sama.",
        .qrStatusWaiting: "Menunggu ponsel memindai kode…",
        .qrStatusPairing: "Kode dipindai. Sedang pairing…",
        .qrFailureTitle: "Gagal pairing dengan kode QR",
        .errorQRTimedOut: "Tidak ada ponsel yang memindai kode tepat waktu. Pastikan ponsel dan Mac ini ada di "
            + "jaringan Wi-Fi yang sama dan jaringan tidak memblokir mDNS, lalu coba lagi.",

        .pairSuccessTitle: "Pairing berhasil",
        .pairSuccessBody: "%@ sudah dipairing. Jika belum muncul di daftar, hubungkan lewat Tersedia lewat Wi-Fi.",
        .wirelessConnectFailureTitle: "Gagal terhubung ke %@",
        .wirelessPairFailureTitle: "Gagal pairing dengan %@",
        .wirelessDisconnectFailureTitle: "Gagal memutus koneksi %@",
        .wirelessSwitchFailureTitle: "Gagal memindahkan %@ ke Wi-Fi",
        .errorNoWiFiAddress: "Perangkat tidak punya alamat IP Wi-Fi. Hubungkan ke Wi-Fi dulu.",
        .errorInvalidAddress: "Masukkan alamat IP yang valid, boleh diikuti port (misalnya 192.168.1.5:5555).",
        .errorInvalidPairingCode: "Masukkan kode pairing 6 digit yang tampil di perangkat.",
        .errorNoRouteHint: "Jika perangkat lain di jaringan ini bisa dijangkau, server adb yang sudah berjalan "
            + "mungkin tidak punya izin Jaringan Lokal. Jalankan adb kill-server, lalu izinkan ADB Monitor di "
            + "Pengaturan Sistem → Privasi & Keamanan → Jaringan Lokal.",

        .prefsWireless: "Wi-Fi:",
        .prefsWirelessDiscovery: "Deteksi perangkat di Wi-Fi",
        .prefsWirelessNote: "Memakai mDNS; sebagian jaringan memblokirnya.",
    ]
}
