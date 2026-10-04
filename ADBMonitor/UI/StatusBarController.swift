//
//  StatusBarController.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import AppKit

/// Abstraksi tampilan menu bar, supaya `AppCoordinator` bisa diuji tanpa membuat `NSStatusItem` sungguhan.
@MainActor
protocol StatusBarRendering: AnyObject {
    /// `nil` berarti belum ada hasil polling pertama.
    func render(_ status: ADBStatus?)
}

/// Memiliki `NSStatusItem` di menu bar dan menyinkronkan tombol serta dropdown dengan `ADBStatus`.
@MainActor
final class StatusBarController: StatusBarRendering {

    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let menuBuilder: StatusMenuBuilder
    private let buttonPresenter = StatusButtonPresenter()
    private var lastStatus: ADBStatus?

    init(actionHandler: StatusMenuActionHandling, localizer: Localizing) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menuBuilder = StatusMenuBuilder(handler: actionHandler, localizer: localizer)
        menu.autoenablesItems = false
        statusItem.menu = menu
        render(nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(languageDidChange),
                                               name: .languageDidChange,
                                               object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func render(_ status: ADBStatus?) {
        lastStatus = status
        if let button = statusItem.button {
            buttonPresenter.apply(status, to: button)
        }
        menuBuilder.populate(menu, for: status)
    }

    /// Bahasa berubah: bangun ulang menu dengan status terakhir tanpa menunggu poll berikutnya.
    @objc private func languageDidChange() {
        render(lastStatus)
    }
}
