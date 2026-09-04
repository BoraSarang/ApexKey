import Foundation

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
        case .time: return "시간"
        case .filesystem: return "파일 시스템"
        case .hardware: return "하드웨어"
        case .network: return "네트워크"
        case .power: return "전원"
        case .system: return "시스템"
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
    
    init(
        id: UUID = UUID(),
        time: DateComponents,
        repeatRule: RepeatRule = .none,
        runImmediately: Bool = true,
        label: String? = nil
    ) {
        self.id = id
        self.time = time
        self.repeatRule = repeatRule
        self.runImmediately = runImmediately
        self.label = label
    }
    
    var displayName: String {
        if let label = label { return label }
        let hour = time.hour ?? 0
        let minute = time.minute ?? 0
        let timeString = String(format: "%02d:%02d", hour, minute)
        let repeatString = repeatRule.displayName
        return "\(timeString) \(repeatString)"
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
        case .none: return "한 번만"
        case .daily: return "매일"
        case .weekdays: return "평일"
        case .weekends: return "주말"
        case .weekly: return "매주"
        case .monthly: return "매월"
        case .custom: return "사용자 지정"
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
    func shouldRun(on date: Date, calendar: Calendar = .current) -> Bool {
        switch self {
        case .none: return true  // 한 번만 실행은 별도 관리
        case .daily: return true
        case .weekdays:
            let weekday = calendar.component(.weekday, from: date)
            return (2...6).contains(weekday)  // 월~금
        case .weekends:
            let weekday = calendar.component(.weekday, from: date)
            return weekday == 1 || weekday == 7  // 일, 토
        case .weekly:
            // 저장된 요일과 비교 필요 (구현 시 저장된 기준 요일 사용)
            return true
        case .monthly:
            // 저장된 날짜와 비교 필요
            return true
        case .custom:
            // 사용자 지정 요일 배열과 비교
            return true
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
        let events = eventTypes.map(\.displayName).joined(separator: ", ")
        let subfolder = watchSubfolders ? " (하위 포함)" : ""
        return "폴더: \(folderName) [\(events)]\(subfolder)"
    }
}

/// 폴더 이벤트 타입
enum FolderEventType: String, Codable, CaseIterable, Identifiable {
    case added = "added"           // 파일 추가
    case modified = "modified"     // 파일 수정
    case removed = "removed"       // 파일 삭제
    case renamed = "renamed"       // 파일 이름 변경
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .added: return "추가"
        case .modified: return "수정"
        case .removed: return "삭제"
        case .renamed: return "이름변경"
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
        return "파일: \(fileURL.lastPathComponent)"
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
        let drive = driveName ?? "모든 드라이브"
        let events = eventTypes.map(\.displayName).joined(separator: ", ")
        return "외장 드라이브: \(drive) [\(events)]"
    }
}

enum DriveEventType: String, Codable, CaseIterable, Identifiable {
    case mounted = "mounted"       // 연결됨
    case unmounted = "unmounted"   // 분리됨
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .mounted: return "연결"
        case .unmounted: return "분리"
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
        let events = eventTypes.map(\.displayName).joined(separator: ", ")
        return "디스플레이 [\(events)]"
    }
}

enum DisplayEventType: String, Codable, CaseIterable, Identifiable {
    case connected = "connected"       // 연결됨
    case disconnected = "disconnected" // 분리됨
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .connected: return "연결"
        case .disconnected: return "분리"
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
        let network = ssid ?? "모든 네트워크"
        let events = eventTypes.map(\.displayName).joined(separator: ", ")
        return "Wi-Fi: \(network) [\(events)]"
    }
}

enum WiFiEventType: String, Codable, CaseIterable, Identifiable {
    case connected = "connected"       // 연결됨
    case disconnected = "disconnected" // 연결 끊김
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .connected: return "연결"
        case .disconnected: return "끊김"
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
        let device = deviceName ?? "모든 기기"
        let events = eventTypes.map(\.displayName).joined(separator: ", ")
        return "블루투스: \(device) [\(events)]"
    }
}

enum BluetoothEventType: String, Codable, CaseIterable, Identifiable {
    case connected = "connected"
    case disconnected = "disconnected"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .connected: return "연결"
        case .disconnected: return "끊김"
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
        return "배터리 \(condition.displayName) \(Int(threshold * 100))%"
    }
}

enum BatteryCondition: String, Codable, CaseIterable, Identifiable {
    case risesAbove = "risesAbove"       // 임계값 초과
    case fallsBelow = "fallsBelow"       // 임계값 미만
    case reaches = "reaches"             // 정확히 도달
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .risesAbove: return "초과"
        case .fallsBelow: return "미만"
        case .reaches: return "도달"
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
        let events = eventTypes.map(\.displayName).joined(separator: ", ")
        return "충전기 [\(events)]"
    }
}

enum ChargerEventType: String, Codable, CaseIterable, Identifiable {
    case connected = "connected"       // 연결됨
    case disconnected = "disconnected" // 분리됨
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .connected: return "연결"
        case .disconnected: return "분리"
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
        let events = eventTypes.map(\.displayName).joined(separator: ", ")
        return "앱: \(bundleID) [\(events)]"
    }
}

enum AppEventType: String, Codable, CaseIterable, Identifiable {
    case launched = "launched"         // 실행됨
    case terminated = "terminated"     // 종료됨
    case activated = "activated"       // 활성화됨 (포커스 얻음)
    case deactivated = "deactivated"   // 비활성화됨
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .launched: return "실행"
        case .terminated: return "종료"
        case .activated: return "활성화"
        case .deactivated: return "비활성화"
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
        let focus = focusName ?? "모든 집중 모드"
        let events = eventTypes.map(\.displayName).joined(separator: ", ")
        return "집중 모드: \(focus) [\(events)]"
    }
}

enum FocusEventType: String, Codable, CaseIterable, Identifiable {
    case turnedOn = "turnedOn"       // 켜짐
    case turnedOff = "turnedOff"     // 꺼짐
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .turnedOn: return "켜짐"
        case .turnedOff: return "꺼짐"
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
        let events = eventTypes.map(\.displayName).joined(separator: ", ")
        return "Stage Manager [\(events)]"
    }
}

enum StageManagerEventType: String, Codable, CaseIterable, Identifiable {
    case turnedOn = "turnedOn"
    case turnedOff = "turnedOff"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .turnedOn: return "켜짐"
        case .turnedOff: return "꺼짐"
        }
    }
}

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