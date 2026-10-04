//
//  NSMenuItem+Factory.swift
//  ADBMonitor
//

import AppKit

extension NSMenuItem {

    /// Item informasi non-interaktif (abu-abu).
    static func info(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    static func command(_ title: String,
                        action: Selector,
                        target: AnyObject,
                        key: String = "",
                        representedObject: Any? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target
        item.representedObject = representedObject
        return item
    }
}
