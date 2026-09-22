//
//  AppDelegate+Menus.swift
//  ApexKey
//
//  System menu bar and status-item context menu
//

import AppKit
import SwiftUI
import Combine

extension AppDelegate {
    // MARK: - 시스템 메뉴바 (Dock 표시 시 명령 제공)

    func setupSystemMenu() {
        NSApp.mainMenu = Self.makeMainMenu(actionTarget: self)
    }

    /// 메뉴 항목 생성 보일러플레이트(NSMenuItem 생성 + target 지정)를 한 곳으로 모음.
    /// target이 nil이면 responder chain을 탄다(편집 메뉴 표준 액션용).
    static func makeItem(title: String, action: Selector?, key: String, target: AnyObject?) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target
        return item
    }

    /// 메인 메뉴 구성 — 테스트에서 구조 검증 가능하도록 순수 빌더로 분리.
    /// target을 nil로 두는 편집 항목들은 responder chain을 타서 포커스된 텍스트 뷰가 처리한다.
    static func makeMainMenu(actionTarget: AnyObject?) -> NSMenu {
        let mainMenu = NSMenu()

        let appMenu = NSMenu()
        let appName = "ApexKey"
        let about = makeItem(title: "ui.menu.about".localizedFormat(appName), action: #selector(AppDelegate.showAboutPanel(_:)), key: "", target: actionTarget)
        let sep1 = NSMenuItem.separator()
        let settings = makeItem(title: "ui.main.settings".localized, action: #selector(AppDelegate.showSettingsPanel(_:)), key: ",", target: actionTarget)
        let sep2 = NSMenuItem.separator()
        let quit = makeItem(title: "ui.menu.quit".localizedFormat(appName), action: #selector(AppDelegate.terminateApp(_:)), key: "q", target: actionTarget)
        appMenu.addItem(about)
        appMenu.addItem(sep1)
        appMenu.addItem(settings)
        appMenu.addItem(sep2)
        appMenu.addItem(quit)

        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // 편집 메뉴 — 없으면 TextEditor/TextField에서 Cmd+C/V/X/A/Z가 동작하지 않음.
        // (AppKit은 메인 메뉴의 표준 edit action을 통해 first responder로 전달)
        let editMenu = NSMenu(title: "ui.edit".localized)
        let editItems: [(String, Selector, String)] = [
            ("ui.menu.undo".localized, Selector("undo:"), "z"),
            ("ui.menu.redo".localized, Selector("redo:"), "Z"),
            ("ui.menu.cut".localized, #selector(NSText.cut(_:)), "x"),
            ("ui.copy".localized, #selector(NSText.copy(_:)), "c"),
            ("ui.menu.paste".localized, #selector(NSText.paste(_:)), "v"),
            ("ui.clear".localized, #selector(NSText.delete(_:)), ""),
            ("ui.menu.select_all".localized, #selector(NSText.selectAll(_:)), "a"),
        ]
        for (index, (title, action, key)) in editItems.enumerated() {
            if index == 2 || index == 6 { editMenu.addItem(.separator()) }
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            // target 미지정 → responder chain (포커스된 텍스트 뷰가 처리)
            editMenu.addItem(item)
        }
        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        return mainMenu
    }

    // MARK: - 툴바/플로팅 창 메뉴 구성 (우클릭 드롭다운)

    func buildMenu() -> NSMenu {
        let menu = NSMenu()
        let openItem = Self.makeItem(title: "ui.open".localized, action: #selector(togglePanelAction(_:)), key: "o", target: self)
        let infoItem = Self.makeItem(title: "ui.info".localized, action: #selector(showAboutPanel(_:)), key: "", target: self)
        let settingsItem = Self.makeItem(title: "ui.main.settings".localized, action: #selector(showSettingsPanel(_:)), key: ",", target: self)
        let updateItem = Self.makeItem(title: "menu.check_update".localized, action: #selector(checkForUpdateAction(_:)), key: "", target: self)
        let debugItem = Self.makeItem(title: "ui.menu.debug_log".localized, action: #selector(showDebugPanel(_:)), key: "", target: self)
        menu.addItem(openItem)
        menu.addItem(infoItem)
        menu.addItem(settingsItem)
        menu.addItem(updateItem)
        menu.addItem(debugItem)
        menu.addItem(.separator())
        menu.addItem(Self.makeItem(title: "ui.quit".localized, action: #selector(terminateApp(_:)), key: "q", target: nil))
        return menu
    }

    // MARK: - 좌/우 클릭 분기

    @objc func handleClick(_ sender: Any?) {
        guard let button = statusItem?.button, let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            Logger.info("AppDelegate", "[MENU] 우클릭 → 컨텍스트 메뉴")
            // 표준 API로 메뉴바 아래 정상 방향의 컨텍스트 메뉴를 펼친다.
            // (popUp(in: nil)은 화면 좌표 역방향으로 열려 "위로" 중첩이 생기는 문제가 있었음)
            NSMenu.popUpContextMenu(buildMenu(), with: event, for: button)
            return
        }
        Logger.info("AppDelegate", "[MENU] 좌클릭 → 패널 토글")
        togglePanel()
    }

    @objc func togglePanelAction(_ sender: Any?) {
        togglePanel()
    }
}
