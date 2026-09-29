import Foundation
import SwiftData

/// 저장소 스키마 버전 1 — **버전 관리 도입 이전의 스키마와 필드가 동일하다** (E-MAC-STORE-5007)
///
/// 이 버전을 "현재 스키마의 이름 붙은 복사본"으로 추가하는 이유는
/// `VersionedSchema`가 없으면 `ShortcutPermissions` 같은 blob 구조에 필드를 추가했을 때
/// 기존 레코드가 전부 디코딩에 실패하고, v0.16의 `corruptedShortcutBlobColumns`가
/// 4컬럼 전부 **영구 쓰기 잠금**이 되기 때문이다 (복구 경로는 `removeShortcut`뿐).
/// 즉 **모델 필드 추가 = 사용자 데이터 소실 위험**이었던 상태.
///
/// 새 버전을 추가하는 규칙:
/// 1. `ConfigSchemaV2` 등 새 `VersionedSchema`를 정의하고 `ConfigMigrationPlan.schemas`에 추가
/// 2. `ConfigMigrationPlan.stages`에 `.lightweight(fromVersion:toVersion:)` 추가.
///    기본값 변경·blob 구조 변경이면 `.custom`로 `MigrationStage` 구현
/// 3. **stage를 절대 건너뛰지 말 것** — 건너뛰면 기존 store가 열리지 않고
///    `quarantineStore`가 발동해 사용자의 모든 설정이 격리된다
enum ConfigSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            PersistedApp.self,
            PersistedBinding.self,
            PersistedScript.self,
            PersistedShortcut.self,
        ]
    }
}

/// 저장소 스키마 이관 계획 — 단계 추가는 위 규칙을 따른다 (E-MAC-STORE-5007)
///
/// 현재는 v1 하나뿐이고 stage가 비어 있다. 이 상태가 안전하다:
/// `init()`이 **버전 관리 이전(무버전) 스키마로 생성된 기존 store를 여는 경로**를
/// 그대로 허용해야 하기 때문이다. 무버전 store는 SwiftData가 내부적으로 v0으로 취급하므로
/// v1까지 경량 이관으로 도달한다. `ApexKeyStoreTests.testUnversionedStoreOpensUnderMigrationPlan`이
/// 이 경로를 고정한다 — **이 테스트가 깨지면 실사용자 데이터가 격리된다.**
enum ConfigMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [ConfigSchemaV1.self]
    }

    /// 아직 이관이 없으므로 비어 있다. stage가 비어 있다는 것은
    /// "무버전 → v1 경량 이관만 수행"한다는 뜻이지, 이관이 불필요하다는 뜻이 아니다.
    static var stages: [MigrationStage] {
        []
    }
}

extension ConfigMigrationPlan {
    /// **컨테이너 생성 시 반드시 이걸 쓸 것.**
    ///
    /// `Schema(ConfigMigrationPlan.schemas)`처럼 쓰면 컴파일되지 않는다
    /// (`Schema.init`는 `[any PersistentModel.Type]`을 받는다). 그리고
    /// `Schema(models)`로만 만들면 `version`이 기본값 `1.0.0`으로 들어가
    /// 버전을 명시하지 않은 새 스키마가 과거와 구분되지 않는다.
    /// 두 가지를 한곳에 묶어 잘못된 생성 지점을 막는다.
    static var currentSchema: Schema {
        guard let latest = schemas.last else {
            // schemas가 비면 컨테이너를 만들 수 없다. 미방어 상태로 두면
            // 기본 스키마(빈)를 써서 사용자 데이터가 보이지 않는 앱이 된다.
            preconditionFailure("ConfigMigrationPlan.schemas가 비어 있음 — 최소 1개 버전을 선언해야 한다")
        }
        return Schema(latest.models, version: latest.versionIdentifier)
    }
}
