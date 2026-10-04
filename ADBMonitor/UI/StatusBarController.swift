//
//  StatusBarController.swift
//  ADBMonitor
//

import AppKit

/// Memiliki `NSStatusItem` di menu bar dan menyinkronkan tombol serta dropdown dengan `ADBStatus`.
@MainActor
final class StatusBarController {

    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let menuBuilder: StatusMenuBuilder
    private let buttonPresenter = StatusButtonPresenter()

    init(actionHandler: StatusMenuActionHandling) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menuBuilder = StatusMenuBuilder(handler: actionHandler)
        menu.autoenablesItems = false
        statusItem.menu = menu
        render(nil)
    }

    deinit {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    /// `nil` berarti belum ada hasil polling pertama.
    func render(_ status: ADBStatus?) {
        if let button = statusItem.button {
            buttonPresenter.apply(status, to: button)
        }
        menuBuilder.populate(menu, for: status)
    }
}
