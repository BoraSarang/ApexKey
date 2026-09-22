//
//  AppDelegate+StatusItem.swift
//  ApexKey
//
//  Status item + dock activation policy
//

import AppKit
import SwiftUI
import Combine

extension AppDelegate {
    // MARK: - 상태 아이템 (showInMenuBar 구동)

    func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let image = NSImage(systemSymbolName: "command.square.fill", accessibilityDescription: "ApexKey")
            image?.isTemplate = true // 메뉴바 단색 템플릿
            button.image = image

            // 좌클릭 → 창 토글, 우클릭 → 메뉴
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
        Logger.info("AppDelegate", "[MENU] 메뉴바 상태 아이템 생성")
    }

    func removeStatusItem() {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
        Logger.info("AppDelegate", "[MENU] 메뉴바 상태 아이템 제거")
    }

    // MARK: - Dock 정책 (showInDock 구동)

    func applyActivationPolicy(_ store: ConfigStore) {
        // .accessory = 메뉴바만(기본), .regular = Dock + 메뉴바
        NSApp.setActivationPolicy(store.showInDock ? .regular : .accessory)
    }
}
