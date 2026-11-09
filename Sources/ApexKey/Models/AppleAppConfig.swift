import Foundation

/// Apple 앱 연동 1 — Notes·Reminders·Calendar 파라미터 (T-214)
///
/// `FileActionConfig`와 같은 규칙을 따른다.
/// - **관대 디코딩**: 모든 필드가 선택값. 하나가 빠져도 저장된 설정 전체가
///   기본값으로 되돌아가지 않는다 (E-MAC-STORE-5008)
/// - 날짜는 **지금으로부터의 분 오프셋**으로 저장한다. 절대 시각 문자열을
///   AppleScript에 넘기면 로케일마다 해석이 달라진다
struct AppleAppConfig: Codable, Hashable {

    /// `noteActions`의 동작 — `createNote`는 제목·본문만 쓴다
    enum NoteOperation: String, Codable, CaseIterable, Hashable {
        case append
        case show
        case createFolder

        var displayName: String {
            switch self {
            case .append: return "apple.note.append".localized
            case .show: return "apple.note.show".localized
            case .createFolder: return "apple.note.create_folder".localized
            }
        }

        var needsTitle: Bool {
            switch self {
            case .append, .show: return true
            case .createFolder: return false
            }
        }
    }

    /// `reminders`의 동작
    enum ReminderOperation: String, Codable, CaseIterable, Hashable {
        case add
        case listLists

        var displayName: String {
            switch self {
            case .add: return "apple.reminder.add".localized
            case .listLists: return "apple.reminder.list_lists".localized
            }
        }
    }

    /// `calendar`의 동작
    enum CalendarOperation: String, Codable, CaseIterable, Hashable {
        case addEvent
        case listCalendars

        var displayName: String {
            switch self {
            case .addEvent: return "apple.calendar.add_event".localized
            case .listCalendars: return "apple.calendar.list_calendars".localized
            }
        }
    }

    /// 제목 (메모 이름 · 미리 알림 제목 · 일정 제목)
    var title: String?
    /// 본문/메모/설명
    var body: String?
    /// `noteActions` 동작 — 기본은 덧붙이기
    var noteOperation: NoteOperation?
    /// 새 폴더 이름 (`createFolder`)
    var folderName: String?
    /// Reminders 목록 이름. 비우면 기본 목록
    var listName: String?
    /// 미리 알림 마감 — 지금부터 분. nil이면 마감 없음
    var dueOffsetMinutes: Int?
    /// Calendar 이름. 비우면 첫 번째 캘린더
    var calendarName: String?
    /// 일정 시작 — 지금부터 분 (기본 60)
    var startOffsetMinutes: Int?
    /// 일정 길이 (분, 기본 60)
    var durationMinutes: Int?
    /// 일정 장소
    var location: String?
    /// `reminders` 동작 — 기본은 추가
    var reminderOperation: ReminderOperation?
    /// `calendar` 동작 — 기본은 일정 추가
    var calendarOperation: CalendarOperation?

    init(
        title: String? = nil,
        body: String? = nil,
        noteOperation: NoteOperation? = nil,
        folderName: String? = nil,
        listName: String? = nil,
        dueOffsetMinutes: Int? = nil,
        calendarName: String? = nil,
        startOffsetMinutes: Int? = nil,
        durationMinutes: Int? = nil,
        location: String? = nil,
        reminderOperation: ReminderOperation? = nil,
        calendarOperation: CalendarOperation? = nil
    ) {
        self.title = title
        self.body = body
        self.noteOperation = noteOperation
        self.folderName = folderName
        self.listName = listName
        self.dueOffsetMinutes = dueOffsetMinutes
        self.calendarName = calendarName
        self.startOffsetMinutes = startOffsetMinutes
        self.durationMinutes = durationMinutes
        self.location = location
        self.reminderOperation = reminderOperation
        self.calendarOperation = calendarOperation
    }

    /// 관대 디코딩 — 모든 필드가 선택값이다
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.title = try c.decodeIfPresent(String.self, forKey: .title)
        self.body = try c.decodeIfPresent(String.self, forKey: .body)
        self.noteOperation = try c.decodeIfPresent(NoteOperation.self, forKey: .noteOperation)
        self.folderName = try c.decodeIfPresent(String.self, forKey: .folderName)
        self.listName = try c.decodeIfPresent(String.self, forKey: .listName)
        self.dueOffsetMinutes = try c.decodeIfPresent(Int.self, forKey: .dueOffsetMinutes)
        self.calendarName = try c.decodeIfPresent(String.self, forKey: .calendarName)
        self.startOffsetMinutes = try c.decodeIfPresent(Int.self, forKey: .startOffsetMinutes)
        self.durationMinutes = try c.decodeIfPresent(Int.self, forKey: .durationMinutes)
        self.location = try c.decodeIfPresent(String.self, forKey: .location)
        self.reminderOperation = try c.decodeIfPresent(ReminderOperation.self, forKey: .reminderOperation)
        self.calendarOperation = try c.decodeIfPresent(CalendarOperation.self, forKey: .calendarOperation)
    }

    static func decode(from data: Data?) -> AppleAppConfig {
        guard let data, !data.isEmpty else { return AppleAppConfig() }
        return (try? JSONDecoder().decode(AppleAppConfig.self, from: data)) ?? AppleAppConfig()
    }

    func encode() -> Data? {
        try? JSONEncoder().encode(self)
    }

    var resolvedNoteOperation: NoteOperation { noteOperation ?? .append }
    var resolvedReminderOperation: ReminderOperation { reminderOperation ?? .add }
    var resolvedCalendarOperation: CalendarOperation { calendarOperation ?? .addEvent }
    var resolvedStartOffset: Int { startOffsetMinutes ?? 60 }
    var resolvedDuration: Int { durationMinutes ?? 60 }
}
