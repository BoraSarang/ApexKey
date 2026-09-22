//
//  AppDelegate+Windowing.swift
//  ApexKey
//
//  KeyCapablePanel / ToastPanel subclasses
//

import AppKit

/// 보더리스 플로팅 패널이 키 포커스(ESC 등)를 받도록 key가 될 수 있게 하는 서브클래스
final class KeyCapablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// 실행 결과 토스트 전용 — 클릭은 받되 key/main이 되지 않아 전면 앱 포커스를 유지한다
final class ToastPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
