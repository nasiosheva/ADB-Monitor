//
//  Translations+Cantonese.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

extension Translations {
    /// Colloquial written Cantonese (Traditional characters): 嘅 咗 唔 冇 喺 緊 搵.
    ///
    /// DRAFT: written by an AI model and not yet reviewed by a native speaker. Review before treating as final.
    static let cantonese: [L10nKey: String] = [
        .menuChecking: "搵緊裝置…",
        .menuNoDevices: "冇連接任何裝置",
        .menuDevicesHeader: "Android 裝置（%@）",
        .menuAdbCustomMissing: "喺自訂路徑搵唔到 ADB：",
        .menuAdbFixInPreferences: "請喺偏好設定度修正。",
        .menuAdbNotInstalled: "未安裝 ADB",
        .menuAdbInstallHint: "請安裝（brew install android-platform-tools）",
        .menuAdbSetPathHint: "或者喺偏好設定指定路徑。",
        .menuAdbError: "ADB 出錯",

        .detailStatus: "狀態",
        .detailSerial: "序號",
        .detailConnection: "連接方式",
        .detailModel: "型號",
        .detailProduct: "產品",
        .detailDevice: "裝置",
        .detailTransportID: "傳輸 ID",
        .labelValue: "%1$@：%2$@",

        .menuCopySerial: "複製序號",
        .menuOpenDeveloperOptions: "開啟開發人員選項",
        .developerOptionsFailureTitle: "喺 %@ 度開啟唔到開發人員選項",
        .menuRefresh: "重新整理",
        .menuPreferences: "偏好設定…",
        .menuQuit: "結束 ADB Monitor",

        .stateConnected: "已連接",
        .stateOffline: "離線",
        .stateUnauthorized: "未授權",
        .stateNoPermissions: "冇權限",
        .stateAuthorizing: "授權緊",
        .stateConnecting: "連接緊",
        .stateRecovery: "復原模式",
        .stateSideload: "Sideload",
        .stateBootloader: "Bootloader",

        .hintUnauthorized: "請喺裝置度㩒「允許 USB 偵錯」。",
        .hintNoPermissions: "請檢查 USB 權限或者 udev 規則。",
        .hintOffline: "請重新接駁裝置，或者重新啟動 adb 伺服器。",

        .connectionUSB: "USB",
        .connectionWiFi: "Wi-Fi",
        .connectionEmulator: "模擬器",
        .connectionUnknown: "未知",

        .powerRestartMenu: "重新啟動裝置…",
        .powerShutdownMenu: "關閉裝置…",
        .powerRestartVerb: "重新啟動",
        .powerShutdownVerb: "關機",
        .powerRestartConfirmTitle: "確定要重新啟動「%@」？",
        .powerShutdownConfirmTitle: "確定要將「%@」關機？",
        .powerRestartConfirmBody: "裝置（%@）會即時重新啟動。裝置上未儲存嘅資料可能會遺失。",
        .powerShutdownConfirmBody: "裝置（%@）會即時關機，而且喺呢部 Mac 度冇辦法再開返機。裝置上未儲存嘅資料可能會遺失。",
        .powerRestartFailureTitle: "重新啟動唔到「%@」",
        .powerShutdownFailureTitle: "關機唔到「%@」",

        .commonCancel: "取消",

        .errorAdbNotFound: "搵唔到 ADB。",
        .errorTimedOut: "adb 冇回應（逾時）。",
        .errorLaunchFailed: "啟動唔到 adb：%@",
        .errorLaunchAtLoginUnsupported: "登入時自動啟動需要 macOS 13 或以上版本。",

        .prefsWindowTitle: "ADB Monitor 偏好設定",
        .prefsAdbPath: "ADB 路徑：",
        .prefsAdbPlaceholder: "自動偵測（留空）",
        .prefsChoose: "揀選…",
        .prefsUsing: "使用緊：%@",
        .prefsAdbNotFound: "搵唔到 ADB",
        .prefsNotExecutable: "唔係可執行檔案",
        .prefsRefreshInterval: "更新間隔：",
        .prefsSeconds: "%@ 秒",
        .prefsStartup: "啟動：",
        .prefsLaunchAtLogin: "登入時自動啟動",
        .prefsLaunchUnsupported: "需要 macOS 13 或以上版本。請用「系統設定」→「登入項目」。",
        .prefsLaunchApproval: "請喺「系統設定」→「一般」→「登入項目」批准。",
        .prefsLanguage: "語言：",
        .prefsLanguageSystem: "跟隨系統",
        .prefsSave: "儲存",
        .prefsSelectAdbPanel: "揀選 adb 可執行檔",

        .menuWirelessHeader: "可以經 Wi-Fi 連接（%@）",
        .menuWirelessConnectItem: "連接去 %@",
        .menuWirelessPairItem: "同 %@ 配對…",
        .menuConnectByAddress: "連接去 IP 位址…",
        .menuPairDevice: "配對裝置…",
        .menuDisconnect: "中斷連接",
        .menuSwitchToWiFi: "轉用 Wi-Fi",

        .connectPromptTitle: "經 Wi-Fi 連接",
        .connectPromptBody: "請輸入裝置嘅 IP 位址。連接埠預設係 5555；如果用無線偵錯，請輸入裝置上顯示嘅連接埠。",
        .connectPromptPlaceholder: "192.168.1.5:5555",
        .connectPromptButton: "連接",
        .pairPromptTitle: "配對裝置",
        .pairPromptBody: "喺裝置度開啟「開發人員選項」→「無線偵錯」→「使用配對碼配對裝置」，然後輸入嗰度顯示嘅位址同配對碼。",
        .pairAddressPlaceholder: "IP 位址同連接埠（192.168.1.5:41223）",
        .pairCodePlaceholder: "6 位數配對碼",
        .pairPromptButton: "配對",

        .pairSuccessTitle: "配對成功",
        .pairSuccessBody: "%@ 已經配對。如果冇喺清單出現，請喺「可以經 Wi-Fi 連接」度連接。",
        .wirelessConnectFailureTitle: "連接唔到 %@",
        .wirelessPairFailureTitle: "同 %@ 配對唔到",
        .wirelessDisconnectFailureTitle: "中斷唔到 %@ 嘅連接",
        .wirelessSwitchFailureTitle: "轉唔到 %@ 用 Wi-Fi",
        .errorNoWiFiAddress: "裝置冇 Wi-Fi IP 位址，請先連接 Wi-Fi。",
        .errorInvalidAddress: "請輸入有效嘅 IP 位址，可以加上連接埠（例如 192.168.1.5:5555）。",
        .errorInvalidPairingCode: "請輸入裝置上顯示嘅 6 位數配對碼。",
        .errorNoRouteHint: "如果網絡上嘅其他裝置連到，可能係已經行緊嘅 adb 伺服器冇「本地網絡」權限。"
            + "請執行 adb kill-server，然後喺「系統設定」→「私隱與安全性」→「本地網絡」允許 ADB Monitor。",

        .prefsWireless: "Wi-Fi：",
        .prefsWirelessDiscovery: "偵測 Wi-Fi 上嘅裝置",
        .prefsWirelessNote: "使用 mDNS；部分網絡會封鎖。",
    ]
}
