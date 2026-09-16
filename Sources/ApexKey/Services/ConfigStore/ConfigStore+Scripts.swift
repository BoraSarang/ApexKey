import Foundation
import SwiftData
import AppKit
import Combine

/// ConfigStore 영역 분할 (R-10) — 동일 클래스 extension, public API 동결.
extension ConfigStore {
    // MARK: - 스크립트 관리

    func addScript(name: String, command: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cmd = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !cmd.isEmpty else { return }
        let script = ScriptItem(name: trimmed, command: cmd)
        guard let context = container?.mainContext else { return }
        context.insert(PersistedScript.from(script))
        saveContext(context)
        scripts.append(script)
    }

    func removeScript(_ script: ScriptItem) {
        scripts.removeAll { $0.id == script.id }
        // 연결된 단축키도 제거
        bindings.filter { $0.actionType == .script && $0.title == script.name }
            .forEach { removeBinding($0) }
        guard let context = container?.mainContext else { return }
        let fetch = FetchDescriptor<PersistedScript>(predicate: #Predicate { $0.id == script.id })
        if let found = fetchContext(context, fetch).first {
            context.delete(found)
        }
        saveContext(context)
    }

    /// 스크립트 실행용 바인딩 (launchApp/메뉴처럼 script 종류 조회)
    func scriptBindings(for scriptID: UUID) -> [HotKeyBinding] {
        guard let script = scripts.first(where: { $0.id == scriptID }) else { return [] }
        return bindings.filter { $0.actionType == .script && $0.title == script.name }
    }

    /// 새 액션 타입 바인딩 (paste, wait, coordinateClick, pauseUntilInput)
    var otherBindings: [HotKeyBinding] {
        bindings.filter {
            [ActionType.paste, .wait, .coordinateClick, .pauseUntilInput, .macro].contains($0.actionType)
        }
    }
}
