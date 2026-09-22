import Foundation

/// 트리거 이벤트 타입이 공통으로 제공하는 현지화된 표시 이름.
protocol TriggerEventDisplayable {
    var displayName: String { get }
}

extension Sequence where Element: TriggerEventDisplayable {
    /// "연결, 분리" 형태의 이벤트 요약 문자열.
    var displaySummary: String {
        map(\.displayName).joined(separator: ", ")
    }
}

/// 자동화 트리거 타입 (enum with associated values 패턴)
enum AutomationTrigger: Identifiable, Codable, Hashable {
    case timeOfDay(TimeOfDayTrigger)
    case folder(FolderTrigger)
    case file(FileTrigger)
    case externalDrive(ExternalDriveTrigger)
    case display(DisplayTrigger)
    case wifi(WiFiTrigger)
    case bluetooth(BluetoothTrigger)
    case battery(BatteryTrigger)
    case charger(ChargerTrigger)
    case app(AppTrigger)
    case focus(FocusTrigger)
    case stageManager(StageManagerTrigger)
    
    var id: UUID {
        switch self {
        case .timeOfDay(let t): return t.id
        case .folder(let t): return t.id
        case .file(let t): return t.id
        case .externalDrive(let t): return t.id
        case .display(let t): return t.id
        case .wifi(let t): return t.id
        case .bluetooth(let t): return t.id
        case .battery(let t): return t.id
        case .charger(let t): return t.id
        case .app(let t): return t.id
        case .focus(let t): return t.id
        case .stageManager(let t): return t.id
        }
    }
    
    var displayName: String {
        switch self {
        case .timeOfDay(let t): return t.displayName
        case .folder(let t): return t.displayName
        case .file(let t): return t.displayName
        case .externalDrive(let t): return t.displayName
        case .display(let t): return t.displayName
        case .wifi(let t): return t.displayName
        case .bluetooth(let t): return t.displayName
        case .battery(let t): return t.displayName
        case .charger(let t): return t.displayName
        case .app(let t): return t.displayName
        case .focus(let t): return t.displayName
        case .stageManager(let t): return t.displayName
        }
    }
    
    var systemImage: String {
        switch self {
        case .timeOfDay: return "clock"
        case .folder: return "folder.badge.gearshape"
        case .file: return "doc.badge.gearshape"
        case .externalDrive: return "externaldrive.badge.timemachine"
        case .display: return "display"
        case .wifi: return "wifi"
        case .bluetooth: return "bluetooth"
        case .battery: return "battery.100"
        case .charger: return "bolt.fill"
        case .app: return "app.badge"
        case .focus: return "moon.fill"
        case .stageManager: return "rectangle.3.group"
        }
    }
    
    var category: TriggerCategory {
        switch self {
        case .timeOfDay: return .time
        case .folder, .file: return .filesystem
        case .externalDrive, .display: return .hardware
        case .wifi, .bluetooth: return .network
        case .battery, .charger: return .power
        case .app, .focus, .stageManager: return .system
        }
    }
    
    var minimumOSVersion: String {
        switch self {
        case .timeOfDay: return "macOS 14.0"
        case .folder, .file, .externalDrive, .display: return "macOS 26.0"
        case .wifi, .bluetooth: return "macOS 26.0"
        case .battery, .charger: return "macOS 26.0"
        case .app, .focus, .stageManager: return "macOS 26.0"
        }
    }

    /// AutomationManager가 실제 감시자를 설치하는 트리거인지.
    /// false면 등록 시 거부 로그 — UI에서도 비활성화한다.
    var isWatcherSupported: Bool {
        switch self {
        case .timeOfDay, .folder, .battery, .charger: return true
        default: return false
        }
    }
    
    /// 트리거가 백그라운드에서 동작하는지 (앱 실행 없이도 작동)
    var runsInBackground: Bool {
        switch self {
        case .timeOfDay, .folder, .file, .externalDrive, .display, .wifi, .bluetooth, .battery, .charger, .app, .focus, .stageManager:
            return true  // macOS 26+ 개인 자동화는 백그라운드 동작
        }
    }
}

/// 트리거 카테고리
enum TriggerCategory: String, Codable, CaseIterable, Identifiable {
    case time = "time"
    case filesystem = "filesystem"
    case hardware = "hardware"
    case network = "network"
    case power = "power"
    case system = "system"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .time: return "trigger.time".localized
        case .filesystem: return "trigger.filesystem".localized
        case .hardware: return "trigger.hardware".localized
        case .network: return "trigger.network".localized
        case .power: return "trigger.power".localized
        case .system: return "trigger.system".localized
        }
    }
    
    var systemImage: String {
        switch self {
        case .time: return "clock"
        case .filesystem: return "folder"
        case .hardware: return "externaldrive"
        case .network: return "wifi"
        case .power: return "battery.100"
        case .system: return "gearshape"
        }
    }
}

/// 시간 트리거
struct TimeOfDayTrigger: Identifiable, Codable, Hashable {
    var id: UUID
    var time: DateComponents           // 시, 분
    var repeatRule: RepeatRule         // 반복 규칙
    var runImmediately: Bool           // 확인 없이 즉시 실행
    var label: String?
    /// weekly 기준 요일 (Calendar weekday: 1=일 ... 7=토)
    var weeklyWeekday: Int?
    /// monthly 기준 날짜 (1...31)
    var monthlyDay: Int?
    /// custom 실행 요일 집합 (Calendar weekday)
    var customWeekdays: Set<Int>?

    init(
        id: UUID = UUID(),
        time: DateComponents,
        repeatRule: RepeatRule = .none,
        runImmediately: Bool = true,
        label: String? = nil,
        weeklyWeekday: Int? = nil,
        monthlyDay: Int? = nil,
        customWeekdays: Set<Int>? = nil
    ) {
        self.id = id
        self.time = time
        self.repeatRule = repeatRule
        self.runImmediately = runImmediately
        self.label = label
        self.weeklyWeekday = weeklyWeekday
        self.monthlyDay = monthlyDay
        self.customWeekdays = customWeekdays
    }

    var displayName: String {
        if let label = label { return label }
        let hour = time.hour ?? 0
        let minute = time.minute ?? 0
        let timeString = String(format: "%02d:%02d", hour, minute)
        let repeatString = repeatDisplayName
        return "\(timeString) \(repeatString)"
    }

    /// 반복 규칙 + 기준 요일/날짜 요약
    var repeatDisplayName: String {
        switch repeatRule {
        case .weekly:
            if let weekday = weeklyWeekday, (1...7).contains(weekday) {
                let symbol = Calendar.current.weekdaySymbols[weekday - 1]
                return "\(repeatRule.displayName) \(symbol)"
            }
            return repeatRule.displayName
        case .monthly:
            if let day = monthlyDay {
                return "\(repeatRule.displayName) \(day)"
            }
            return repeatRule.displayName
        case .custom:
            if let days = customWeekdays, !days.isEmpty {
                let symbols = days.sorted()
                    .compactMap { $0 >= 1 && $0 <= 7 ? Calendar.current.weekdaySymbols[$0 - 1] : nil }
                return "\(repeatRule.displayName) \(symbols.joined(separator: ","))"
            }
            return repeatRule.displayName
        default:
            return repeatRule.displayName
        }
    }

    /// 해당 시각에 실행해야 하는지 (기준 요일/날짜 포함)
    func shouldRun(on date: Date, calendar: Calendar = .current) -> Bool {
        switch repeatRule {
        case .none, .daily, .weekdays, .weekends:
            return repeatRule.shouldRun(on: date, calendar: calendar)
        case .weekly:
            guard let weekday = weeklyWeekday, (1...7).contains(weekday) else { return false }
            return calendar.component(.weekday, from: date) == weekday
        case .monthly:
            guard let day = monthlyDay, (1...31).contains(day) else { return false }
            return calendar.component(.day, from: date) == day
        case .custom:
            guard let days = customWeekdays, !days.isEmpty else { return false }
            return days.contains(calendar.component(.weekday, from: date))
        }
    }
}

/// 반복 규칙
enum RepeatRule: String, Codable, CaseIterable, Identifiable {
    case none = "none"           // 한 번만
    case daily = "daily"         // 매일
    case weekdays = "weekdays"   // 평일
    case weekends = "weekends"   // 주말
    case weekly = "weekly"       // 매주 (같은 요일)
    case monthly = "monthly"     // 매월 (같은 날짜)
    case custom = "custom"       // 사용자 지정 (요일 선택)
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .none: return "repeat.none".localized
        case .daily: return "repeat.daily".localized
        case .weekdays: return "repeat.weekdays".localized
        case .weekends: return "repeat.weekends".localized
        case .weekly: return "repeat.weekly".localized
        case .monthly: return "repeat.monthly".localized
        case .custom: return "repeat.custom".localized
        }
    }
    
    var systemImage: String {
        switch self {
        case .none: return "1.circle"
        case .daily: return "repeat"
        case .weekdays: return "calendar.badge.clock"
        case .weekends: return "calendar.badge.plus"
        case .weekly: return "calendar"
        case .monthly: return "calendar.circle"
        case .custom: return "slider.horizontal.3"
        }
    }
    
    /// 해당 날짜에 실행되어야 하는지 확인
    /// weekly/monthly/custom은 기준 요일·날짜가 필요하므로 TimeOfDayTrigger.shouldRun을 사용한다.
    func shouldRun(on date: Date, calendar: Calendar = .current) -> Bool {
        switch self {
        case .none: return true  // 1회성 여부는 AutomationManager가 UserDefaults로 가드
        case .daily: return true
        case .weekdays:
            let weekday = calendar.component(.weekday, from: date)
            return (2...6).contains(weekday)  // 월~금
        case .weekends:
            let weekday = calendar.component(.weekday, from: date)
            return weekday == 1 || weekday == 7  // 일, 토
        case .weekly, .monthly, .custom:
            // 기준 필드 없이 단독 호출 시 미실행 (TimeOfDayTrigger 경로로 우회해야 함)
            return false
        }
    }
}

/// 폴더 감시 트리거
struct FolderTrigger: Identifiable, Codable, Hashable {
    var id: UUID
    var folderPath: String              // 감시할 폴더 경로
    var watchSubfolders: Bool           // 하위 폴더 포함
    var eventTypes: Set<FolderEventType> // 감시할 이벤트 타입
    var runImmediately: Bool            // 확인 없이 즉시 실행
    var ignorePatterns: [String]        // 무시할 파일 패턴 (glob)
    var label: String?
    
    init(
        id: UUID = UUID(),
        folderPath: String,
        watchSubfolders: Bool = false,
        eventTypes: Set<FolderEventType> = [.added],
        runImmediately: Bool = true,
        ignorePatterns: [String] = [],
        label: String? = nil
    ) {
        self.id = id
        self.folderPath = folderPath
        self.watchSubfolders = watchSubfolders
        self.eventTypes = eventTypes
        self.runImmediately = runImmediately
        self.ignorePatterns = ignorePatterns
        self.label = label
    }
    
    var folderURL: URL {
        URL(fileURLWithPath: folderPath)
    }
    
    var displayName: String {
        if let label = label { return label }
        let folderName = folderURL.lastPathComponent
        let events = eventTypes.displaySummary
        let subfolder = watchSubfolders ? "ui.trigger.subfolder_suffix".localized : ""
        return "ui.trigger.folder_fmt".localizedFormat(folderName, events, subfolder)
    }
}

/// 폴더 이벤트 타입
enum FolderEventType: String, Codable, CaseIterable, Identifiable, TriggerEventDisplayable {
    case added = "added"           // 파일 추가
    case modified = "modified"     // 파일 수정
    case removed = "removed"       // 파일 삭제
    case renamed = "renamed"       // 파일 이름 변경
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .added: return "ui.add".localized
        case .modified: return "ui.trigger.modified".localized
        case .removed: return "ui.delete".localized
        case .renamed: return "ui.trigger.renamed".localized
        }
    }
    
    var systemImage: String {
        switch self {
        case .added: return "plus.circle"
        case .modified: return "pencil.circle"
        case .removed: return "minus.circle"
        case .renamed: return "arrow.left.arrow.right.circle"
        }
    }
}

/// 파일 감시 트리거 (단일 파일)
struct FileTrigger: Identifiable, Codable, Hashable {
    var id: UUID
    var filePath: String              // 감시할 파일 경로
    var runImmediately: Bool
    var label: String?
    
    init(
        id: UUID = UUID(),
        filePath: String,
        runImmediately: Bool = true,
        label: String? = nil
    ) {
        self.id = id
        self.filePath = filePath
        self.runImmediately = runImmediately
        self.label = label
    }
    
    var fileURL: URL {
        URL(fileURLWithPath: filePath)
    }
    
    var displayName: String {
        if let label = label { return label }
        return "ui.trigger.file_fmt".localizedFormat(fileURL.lastPathComponent)
    }
}

/// 외장 드라이브 트리거
struct ExternalDriveTrigger: Identifiable, Codable, Hashable {
    var id: UUID
    var driveName: String?            // 특정 드라이브명 (nil = 모든 드라이브)
    var eventTypes: Set<DriveEventType>
    var runImmediately: Bool
    var label: String?
    
    init(
        id: UUID = UUID(),
        driveName: String? = nil,
        eventTypes: Set<DriveEventType> = [.mounted],
        runImmediately: Bool = true,
        label: String? = nil
    ) {
        self.id = id
        self.driveName = driveName
        self.eventTypes = eventTypes
        self.runImmediately = runImmediately
        self.label = label
    }
    
    var displayName: String {
        if let label = label { return label }
        let drive = driveName ?? "ui.trigger.all_drives".localized
        let events = eventTypes.displaySummary
        return "ui.trigger.drive_fmt".localizedFormat(drive, events)
    }
}

enum DriveEventType: String, Codable, CaseIterable, Identifiable, TriggerEventDisplayable {
    case mounted = "mounted"       // 연결됨
    case unmounted = "unmounted"   // 분리됨
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .mounted: return "ui.trigger.connected".localized
        case .unmounted: return "ui.trigger.disconnected".localized
        }
    }
}

/// 디스플레이 트리거
struct DisplayTrigger: Identifiable, Codable, Hashable {
    var id: UUID
    var eventTypes: Set<DisplayEventType>
    var runImmediately: Bool
    var label: String?
    
    init(
        id: UUID = UUID(),
        eventTypes: Set<DisplayEventType> = [.connected],
        runImmediately: Bool = true,
        label: String? = nil
    ) {
        self.id = id
        self.eventTypes = eventTypes
        self.runImmediately = runImmediately
        self.label = label
    }
    
    var displayName: String {
        if let label = label { return label }
        let events = eventTypes.displaySummary
        return "ui.trigger.display_fmt".localizedFormat(events)
    }
}

enum DisplayEventType: String, Codable, CaseIterable, Identifiable, TriggerEventDisplayable {
    case connected = "connected"       // 연결됨
    case disconnected = "disconnected" // 분리됨
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .connected: return "ui.trigger.connected".localized
        case .disconnected: return "ui.trigger.disconnected".localized
        }
    }
}

/// Wi-Fi 트리거
struct WiFiTrigger: Identifiable, Codable, Hashable {
    var id: UUID
    var ssid: String?                 // 특정 SSID (nil = 모든 네트워크)
    var eventTypes: Set<WiFiEventType>
    var runImmediately: Bool
    var label: String?
    
    init(
        id: UUID = UUID(),
        ssid: String? = nil,
        eventTypes: Set<WiFiEventType> = [.connected],
        runImmediately: Bool = true,
        label: String? = nil
    ) {
        self.id = id
        self.ssid = ssid
        self.eventTypes = eventTypes
        self.runImmediately = runImmediately
        self.label = label
    }
    
    var displayName: String {
        if let label = label { return label }
        let network = ssid ?? "ui.trigger.all_networks".localized
        let events = eventTypes.displaySummary
        return "ui.trigger.wifi_fmt".localizedFormat(network, events)
    }
}

enum WiFiEventType: String, Codable, CaseIterable, Identifiable, TriggerEventDisplayable {
    case connected = "connected"       // 연결됨
    case disconnected = "disconnected" // 연결 끊김
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .connected: return "ui.trigger.connected".localized
        case .disconnected: return "ui.trigger.wifi_disconnected".localized
        }
    }
}

/// 블루투스 트리거
struct BluetoothTrigger: Identifiable, Codable, Hashable {
    var id: UUID
    var deviceName: String?           // 특정 기기명 (nil = 모든 기기)
    var eventTypes: Set<BluetoothEventType>
    var runImmediately: Bool
    var label: String?
    
    init(
        id: UUID = UUID(),
        deviceName: String? = nil,
        eventTypes: Set<BluetoothEventType> = [.connected],
        runImmediately: Bool = true,
        label: String? = nil
    ) {
        self.id = id
        self.deviceName = deviceName
        self.eventTypes = eventTypes
        self.runImmediately = runImmediately
        self.label = label
    }
    
    var displayName: String {
        if let label = label { return label }
        let device = deviceName ?? "ui.trigger.all_devices".localized
        let events = eventTypes.displaySummary
        return "ui.trigger.bluetooth_fmt".localizedFormat(device, events)
    }
}

enum BluetoothEventType: String, Codable, CaseIterable, Identifiable, TriggerEventDisplayable {
    case connected = "connected"
    case disconnected = "disconnected"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .connected: return "ui.trigger.connected".localized
        case .disconnected: return "ui.trigger.wifi_disconnected".localized
        }
    }
}

/// 배터리 트리거 (노트북만)
struct BatteryTrigger: Identifiable, Codable, Hashable {
    var id: UUID
    var condition: BatteryCondition
    var threshold: Double             // 0.0 ~ 1.0
    var runImmediately: Bool
    var label: String?
    
    init(
        id: UUID = UUID(),
        condition: BatteryCondition = .fallsBelow,
        threshold: Double = 0.2,
        runImmediately: Bool = true,
        label: String? = nil
    ) {
        self.id = id
        self.condition = condition
        self.threshold = threshold
        self.runImmediately = runImmediately
        self.label = label
    }
    
    var displayName: String {
        if let label = label { return label }
        return "ui.trigger.battery_fmt".localizedFormat(condition.displayName, Int(threshold * 100))
    }
}

enum BatteryCondition: String, Codable, CaseIterable, Identifiable {
    case risesAbove = "risesAbove"       // 임계값 초과
    case fallsBelow = "fallsBelow"       // 임계값 미만
    case reaches = "reaches"             // 정확히 도달
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .risesAbove: return "ui.trigger.rises_above".localized
        case .fallsBelow: return "ui.trigger.falls_below".localized
        case .reaches: return "ui.trigger.reaches".localized
        }
    }
}

/// 충전기 트리거 (노트북만)
struct ChargerTrigger: Identifiable, Codable, Hashable {
    var id: UUID
    var eventTypes: Set<ChargerEventType>
    var runImmediately: Bool
    var label: String?
    
    init(
        id: UUID = UUID(),
        eventTypes: Set<ChargerEventType> = [.connected],
        runImmediately: Bool = true,
        label: String? = nil
    ) {
        self.id = id
        self.eventTypes = eventTypes
        self.runImmediately = runImmediately
        self.label = label
    }
    
    var displayName: String {
        if let label = label { return label }
        let events = eventTypes.displaySummary
        return "ui.trigger.charger_fmt".localizedFormat(events)
    }
}

enum ChargerEventType: String, Codable, CaseIterable, Identifiable, TriggerEventDisplayable {
    case connected = "connected"       // 연결됨
    case disconnected = "disconnected" // 분리됨
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .connected: return "ui.trigger.connected".localized
        case .disconnected: return "ui.trigger.disconnected".localized
        }
    }
}

/// 앱 실행/종료 트리거
struct AppTrigger: Identifiable, Codable, Hashable {
    var id: UUID
    var bundleID: String              // 대상 앱 번들 ID
    var eventTypes: Set<AppEventType>
    var runImmediately: Bool
    var label: String?
    
    init(
        id: UUID = UUID(),
        bundleID: String,
        eventTypes: Set<AppEventType> = [.launched],
        runImmediately: Bool = true,
        label: String? = nil
    ) {
        self.id = id
        self.bundleID = bundleID
        self.eventTypes = eventTypes
        self.runImmediately = runImmediately
        self.label = label
    }
    
    var displayName: String {
        if let label = label { return label }
        let events = eventTypes.displaySummary
        return "ui.trigger.app_fmt".localizedFormat(bundleID, events)
    }
}

enum AppEventType: String, Codable, CaseIterable, Identifiable, TriggerEventDisplayable {
    case launched = "launched"         // 실행됨
    case terminated = "terminated"     // 종료됨
    case activated = "activated"       // 활성화됨 (포커스 얻음)
    case deactivated = "deactivated"   // 비활성화됨
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .launched: return "ui.run".localized
        case .terminated: return "ui.quit".localized
        case .activated: return "ui.trigger.activated".localized
        case .deactivated: return "ui.trigger.deactivated".localized
        }
    }
}

/// 집중 모드 트리거
struct FocusTrigger: Identifiable, Codable, Hashable {
    var id: UUID
    var focusName: String?            // 특정 집중 모드 (nil = 모든 모드)
    var eventTypes: Set<FocusEventType>
    var runImmediately: Bool
    var label: String?
    
    init(
        id: UUID = UUID(),
        focusName: String? = nil,
        eventTypes: Set<FocusEventType> = [.turnedOn],
        runImmediately: Bool = true,
        label: String? = nil
    ) {
        self.id = id
        self.focusName = focusName
        self.eventTypes = eventTypes
        self.runImmediately = runImmediately
        self.label = label
    }
    
    var displayName: String {
        if let label = label { return label }
        let focus = focusName ?? "ui.trigger.all_focus".localized
        let events = eventTypes.displaySummary
        return "ui.trigger.focus_fmt".localizedFormat(focus, events)
    }
}

enum FocusEventType: String, Codable, CaseIterable, Identifiable, TriggerEventDisplayable {
    case turnedOn = "turnedOn"       // 켜짐
    case turnedOff = "turnedOff"     // 꺼짐
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .turnedOn: return "ui.trigger.turned_on".localized
        case .turnedOff: return "ui.trigger.turned_off".localized
        }
    }
}

/// Stage Manager 트리거
struct StageManagerTrigger: Identifiable, Codable, Hashable {
    var id: UUID
    var eventTypes: Set<StageManagerEventType>
    var runImmediately: Bool
    var label: String?
    
    init(
        id: UUID = UUID(),
        eventTypes: Set<StageManagerEventType> = [.turnedOn],
        runImmediately: Bool = true,
        label: String? = nil
    ) {
        self.id = id
        self.eventTypes = eventTypes
        self.runImmediately = runImmediately
        self.label = label
    }
    
    var displayName: String {
        if let label = label { return label }
        let events = eventTypes.displaySummary
        return "Stage Manager [\(events)]"
    }
}

/// FocusEventType과 완전히 동일(켜짐/꺼짐)하므로 별도 정의 없이 공유한다.
/// rawValue가 같아 기존 저장 데이터(Codable) 호환성도 유지된다.
typealias StageManagerEventType = FocusEventType

/// 트리거 이벤트 데이터 (실행 시 단축어에 전달되는 입력)
struct TriggerEventData: Codable, Hashable {
    var triggerID: UUID
    var triggerType: String
    var timestamp: Date
    var data: [String: VariableValue]  // 트리거별 추가 데이터
    
    // 폴더 이벤트
    static func folderEvent(triggerID: UUID, eventType: FolderEventType, fileURLs: [URL]) -> TriggerEventData {
        TriggerEventData(
            triggerID: triggerID,
            triggerType: "folder",
            timestamp: Date(),
            data: [
                "eventType": .text(eventType.rawValue),
                "files": .list(fileURLs.map { .file($0) }),
                "filePaths": .list(fileURLs.map { .text($0.path) })
            ]
        )
    }
    
    // 파일 이벤트
    static func fileEvent(triggerID: UUID, fileURL: URL) -> TriggerEventData {
        TriggerEventData(
            triggerID: triggerID,
            triggerType: "file",
            timestamp: Date(),
            data: [
                "file": .file(fileURL),
                "filePath": .text(fileURL.path)
            ]
        )
    }
    
    // 드라이브 이벤트
    static func driveEvent(triggerID: UUID, eventType: DriveEventType, driveName: String, mountPoint: String?) -> TriggerEventData {
        TriggerEventData(
            triggerID: triggerID,
            triggerType: "externalDrive",
            timestamp: Date(),
            data: [
                "eventType": .text(eventType.rawValue),
                "driveName": .text(driveName),
                "mountPoint": mountPoint.map { .text($0) } ?? .null
            ]
        )
    }
    
    // 시간 이벤트
    static func timeEvent(triggerID: UUID) -> TriggerEventData {
        TriggerEventData(
            triggerID: triggerID,
            triggerType: "timeOfDay",
            timestamp: Date(),
            data: [
                "triggeredAt": .date(Date())
            ]
        )
    }
    
    // 앱 이벤트
    static func appEvent(triggerID: UUID, eventType: AppEventType, bundleID: String) -> TriggerEventData {
        TriggerEventData(
            triggerID: triggerID,
            triggerType: "app",
            timestamp: Date(),
            data: [
                "eventType": .text(eventType.rawValue),
                "bundleID": .text(bundleID)
            ]
        )
    }
    
    /// 단축어 입력 변수용 VariableValue로 변환
    func toVariableValue() -> VariableValue {
        .dictionary(data)
    }
}