import Foundation
import SwiftUI

/// 워크플로우 목록 순서 (T-192).
///
/// `PersistedShortcut`에 순서 컬럼이 없어 SwiftData fetch 순서는 무보장이다.
/// 스키마 변경(VersionedSchema 마이그레이션) 대신 UserDefaults에 ID 배열을 둔다 —
/// blob·스키마를 건드리지 않으므로 저장 안전성 규칙과 충돌하지 않는다.
extension ConfigStore {
    /// 저장된 순서로 정렬. 저장에 없는 ID(신규)는 로드 순서대로 뒤에 둔다.
    func applyShortcutOrder() {
        let saved = (defaults.array(forKey: PrefKeys.shortcutOrder) as? [String]) ?? []
        guard !saved.isEmpty else { return }
        let rank = Dictionary(uniqueKeysWithValues: saved.enumerated().map { ($1, $0) })
        shortcuts.sort {
            switch (rank[$0.id.uuidString], rank[$1.id.uuidString]) {
            case let (a?, b?): return a < b
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return false
            }
        }
    }

    /// 현재 메모리 순서를 저장.
    func persistShortcutOrder() {
        defaults.set(shortcuts.map(\.id.uuidString), forKey: PrefKeys.shortcutOrder)
    }

    /// 목록 순서 이동 (List onMove 의미).
    func moveShortcuts(from source: IndexSet, to destination: Int) {
        shortcuts.move(fromOffsets: source, toOffset: destination)
        persistShortcutOrder()
    }
}
