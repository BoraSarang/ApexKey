import Foundation
import SwiftData

/// 사용자 정의 스크립트 (셸 명령)
struct ScriptItem: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var command: String

    init(id: UUID = UUID(), name: String, command: String) {
        self.id = id
        self.name = name
        self.command = command
    }
}

/// SwiftData 영속 모델 — 스크립트
@Model
final class PersistedScript {
    var id: UUID
    var name: String
    var command: String

    init(id: UUID = UUID(), name: String, command: String) {
        self.id = id
        self.name = name
        self.command = command
    }

    func toScript() -> ScriptItem {
        ScriptItem(id: id, name: name, command: command)
    }

    static func from(_ s: ScriptItem) -> PersistedScript {
        PersistedScript(id: s.id, name: s.name, command: s.command)
    }
}
