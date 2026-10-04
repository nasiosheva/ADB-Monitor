//
//  Translations+Chinese.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

extension Translations {
    /// Mandarin Tradisional, istilah mengikuti macOS Taiwan (偏好設定, 結束, 拷貝, 登入項目).
    static let chinese: [L10nKey: String] = [
        .menuChecking: "正在偵測裝置…",
        .menuNoDevices: "沒有已連線的裝置",
        .menuDevicesHeader: "Android 裝置（%@）",
        .menuAdbCustomMissing: "在自訂路徑找不到 ADB：",
        .menuAdbFixInPreferences: "請至偏好設定修正。",
        .menuAdbNotInstalled: "尚未安裝 ADB",
        .menuAdbInstallHint: "請安裝（brew install android-platform-tools）",
        .menuAdbSetPathHint: "或在偏好設定中指定路徑。",
        .menuAdbError: "ADB 錯誤",

        .detailStatus: "狀態",
        .detailSerial: "序號",
        .detailConnection: "連線方式",
        .detailModel: "型號",
        .detailProduct: "產品",
        .detailDevice: "裝置",
        .detailTransportID: "傳輸 ID",
        .labelValue: "%1$@：%2$@",

        .menuCopySerial: "拷貝序號",
        .menuRefresh: "重新整理",
        .menuPreferences: "偏好設定…",
        .menuQuit: "結束 ADB Monitor",

        .stateConnected: "已連線",
        .stateOffline: "離線",
        .stateUnauthorized: "未授權",
        .stateNoPermissions: "無權限",
        .stateAuthorizing: "授權中",
        .stateConnecting: "連線中",
        .stateRecovery: "復原模式",
        .stateSideload: "Sideload",
        .stateBootloader: "Bootloader",

        .hintUnauthorized: "請在裝置上允許 USB 偵錯提示。",
        .hintNoPermissions: "請檢查 USB 權限或 udev 規則。",
        .hintOffline: "請重新連接裝置，或重新啟動 adb 伺服器。",

        .connectionUSB: "USB",
        .connectionWiFi: "Wi-Fi",
        .connectionEmulator: "模擬器",
        .connectionUnknown: "未知",

        .powerRestartMenu: "重新啟動裝置…",
        .powerShutdownMenu: "關閉裝置…",
        .powerRestartVerb: "重新啟動",
        .powerShutdownVerb: "關機",
        .powerRestartConfirmTitle: "要重新啟動「%@」嗎？",
        .powerShutdownConfirmTitle: "要將「%@」關機嗎？",
        .powerRestartConfirmBody: "裝置（%@）將立即重新啟動。裝置上未儲存的資料可能會遺失。",
        .powerShutdownConfirmBody: "裝置（%@）將立即關機，且無法從這台 Mac 重新開機。裝置上未儲存的資料可能會遺失。",
        .powerRestartFailureTitle: "無法重新啟動「%@」",
        .powerShutdownFailureTitle: "無法將「%@」關機",

        .commonCancel: "取消",

        .errorAdbNotFound: "找不到 ADB。",
        .errorTimedOut: "adb 沒有回應（逾時）。",
        .errorLaunchFailed: "無法啟動 adb：%@",
        .errorLaunchAtLoginUnsupported: "登入時自動開啟需要 macOS 13 或更新版本。",

        .prefsWindowTitle: "ADB Monitor 偏好設定",
        .prefsAdbPath: "ADB 路徑：",
        .prefsAdbPlaceholder: "自動偵測（留空）",
        .prefsChoose: "選擇…",
        .prefsUsing: "使用中：%@",
        .prefsAdbNotFound: "找不到 ADB",
        .prefsNotExecutable: "不是可執行檔案",
        .prefsRefreshInterval: "更新間隔：",
        .prefsSeconds: "%@ 秒",
        .prefsStartup: "啟動：",
        .prefsLaunchAtLogin: "登入時自動開啟",
        .prefsLaunchUnsupported: "需要 macOS 13 或更新版本。請使用「系統設定」→「登入項目」。",
        .prefsLaunchApproval: "請至「系統設定」→「一般」→「登入項目」中核准。",
        .prefsLanguage: "語言：",
        .prefsLanguageSystem: "跟隨系統",
        .prefsSave: "儲存",
        .prefsSelectAdbPanel: "選擇 adb 可執行檔",
    ]
}
