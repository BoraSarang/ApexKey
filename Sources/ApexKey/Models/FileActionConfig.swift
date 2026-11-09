import Foundation

/// 파일 액션 파라미터 — `step.actionParameters`에 JSON으로 저장된다 (T-213)
///
/// 설계 근거는 `FileOpenConfig`·`TerminalOpenConfig`와 같다.
/// - **관대 디코딩**: 필드가 빠져도 디코딩이 실패하면 안 된다. 실패하면 저장된 설정이
///   조용히 기본값으로 되돌아간다 (E-MAC-STORE-5008)
/// - 파일을 **변경하는** 동작(이동·이름 변경·삭제)은 `confirmBeforeChange`가 기본 `true`다.
///   자동화에서 확인 창을 끄고 싶을 때만 사용자가 명시적으로 해제한다
struct FileActionConfig: Codable, Hashable {

    /// `fileActions`의 동작
    enum Operation: String, Codable, CaseIterable, Hashable {
        case copy
        case move
        case duplicate
        case trash
        case reveal

        var displayName: String {
            switch self {
            case .copy: return "file.operation.copy".localized
            case .move: return "file.operation.move".localized
            case .duplicate: return "file.operation.duplicate".localized
            case .trash: return "file.operation.trash".localized
            case .reveal: return "file.operation.reveal".localized
            }
        }

        /// 사용자 데이터를 바꾸는 동작 — 확인 기본값이 켜진다
        var changesData: Bool {
            switch self {
            case .copy, .move, .duplicate, .trash: return true
            case .reveal: return false
            }
        }
    }

    /// `externalStorage`의 동작
    enum StorageMode: String, Codable, CaseIterable, Hashable {
        case list
        case copy

        var displayName: String {
            switch self {
            case .list: return "file.storage.list".localized
            case .copy: return "file.storage.copy".localized
            }
        }
    }

    /// 입력 경로 — 줄바꿈으로 여러 개. 비우면 이전 단계 출력 또는 `target`을 쓴다
    var sourcePaths: String?
    /// 대상 폴더 (이동·이름 변경·압축 풀기·외부 저장소 하위 경로·첨부 저장 폴더)
    var destination: String?
    /// 하위 폴더까지 찾기 (`getFiles`)
    var recursive: Bool?
    /// 숨김 파일 포함 (`getFiles`)
    var includeHidden: Bool?
    /// 확장자 필터 — 쉼표 구분 (`pdf, jpg`). 비우면 전부
    var extensions: String?
    /// `fileActions` 동작
    var operation: Operation?
    /// `externalStorage` 동작 — 기본은 목록
    var storageMode: StorageMode?
    /// `externalStorage` 대상 볼륨 이름. 비우면 외부 볼륨이 하나일 때 자동
    var volumeName: String?

    // === 이름 바꾸기 ===
    /// 이름 템플릿 — `{name}` `{index}` `{date}` `{ext}` 지원
    var template: String?
    /// 찾을 문자열 (템플릿이 비었을 때)
    var findText: String?
    /// 바꿀 문자열
    var replaceText: String?
    /// `{index}` 시작 번호
    var startNumber: Int?

    // === 안전장치 ===
    /// 같은 이름이 있으면 덮어쓰기 (기본 false — 충돌은 실패로 알린다)
    var overwrite: Bool?
    /// 변경 전 확인 창 (기본 true)
    var confirmBeforeChange: Bool?

    init(
        sourcePaths: String? = nil,
        destination: String? = nil,
        recursive: Bool? = nil,
        includeHidden: Bool? = nil,
        extensions: String? = nil,
        operation: Operation? = nil,
        storageMode: StorageMode? = nil,
        volumeName: String? = nil,
        template: String? = nil,
        findText: String? = nil,
        replaceText: String? = nil,
        startNumber: Int? = nil,
        overwrite: Bool? = nil,
        confirmBeforeChange: Bool? = nil
    ) {
        self.sourcePaths = sourcePaths
        self.destination = destination
        self.recursive = recursive
        self.includeHidden = includeHidden
        self.extensions = extensions
        self.operation = operation
        self.storageMode = storageMode
        self.volumeName = volumeName
        self.template = template
        self.findText = findText
        self.replaceText = replaceText
        self.startNumber = startNumber
        self.overwrite = overwrite
        self.confirmBeforeChange = confirmBeforeChange
    }

    /// 관대 디코딩 — 모든 필드가 선택값이다
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.sourcePaths = try c.decodeIfPresent(String.self, forKey: .sourcePaths)
        self.destination = try c.decodeIfPresent(String.self, forKey: .destination)
        self.recursive = try c.decodeIfPresent(Bool.self, forKey: .recursive)
        self.includeHidden = try c.decodeIfPresent(Bool.self, forKey: .includeHidden)
        self.extensions = try c.decodeIfPresent(String.self, forKey: .extensions)
        self.operation = try c.decodeIfPresent(Operation.self, forKey: .operation)
        self.storageMode = try c.decodeIfPresent(StorageMode.self, forKey: .storageMode)
        self.volumeName = try c.decodeIfPresent(String.self, forKey: .volumeName)
        self.template = try c.decodeIfPresent(String.self, forKey: .template)
        self.findText = try c.decodeIfPresent(String.self, forKey: .findText)
        self.replaceText = try c.decodeIfPresent(String.self, forKey: .replaceText)
        self.startNumber = try c.decodeIfPresent(Int.self, forKey: .startNumber)
        self.overwrite = try c.decodeIfPresent(Bool.self, forKey: .overwrite)
        self.confirmBeforeChange = try c.decodeIfPresent(Bool.self, forKey: .confirmBeforeChange)
    }

    /// `actionParameters`에서 안전하게 복원 — 없거나 깨졌으면 기본값
    static func decode(from data: Data?) -> FileActionConfig {
        guard let data, !data.isEmpty else { return FileActionConfig() }
        return (try? JSONDecoder().decode(FileActionConfig.self, from: data)) ?? FileActionConfig()
    }

    func encode() -> Data? {
        try? JSONEncoder().encode(self)
    }

    var shouldConfirm: Bool { confirmBeforeChange ?? true }
    var shouldOverwrite: Bool { overwrite ?? false }
}
