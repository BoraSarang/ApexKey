import Foundation
import AppKit
import CoreServices
import IOKit.ps

/// 자동화 트리거 관리자 — 등록된 AutomationTrigger를 감시하고 이벤트 발생 시 단축어 실행
final class AutomationManager {
    static let shared = AutomationManager()
    
    /// 트리거 등록 항목 (단축어 + 트리거 페어)
    private struct Registration {
        let shortcutID: UUID
        let shortcutName: String
        let trigger: AutomationTrigger
    }
    
    /// 이벤트 발생 시 콜백 (단축어 실행)
    var onTriggerFired: ((UUID, AutomationTrigger, TriggerEventData) -> Void)?
    
    private var registrations: [Registration] = []
    private var folderStreams: [FSEventStreamRef] = []
    /// 각 폴더 스트림의 콜백 큐 — 해제 전에 동기화하기 위해 보관한다 (E-MAC-AUTO-8002)
    private var folderStreamQueues: [DispatchQueue] = []
    /// 파일 트리거 스트림 — 부모 폴더를 감시하고 대상 경로만 골라 발동한다
    private var fileStreams: [FSEventStreamRef] = []
    private var fileStreamQueues: [DispatchQueue] = []
    /// 외장 드라이브·앱 알림 옵저버 (NSWorkspace 알림 센터)
    private var workspaceObservers: [NSObjectProtocol] = []
    /// 디스플레이 구성 변경 옵저버
    private var displayObserver: NSObjectProtocol?
    private var lastDisplayCount: Int = 0
    /// 폴더 이벤트 콜백 전용 큐 — stopAllWatchers에서 barrier로 비울 수 있도록 전역 관리한다
    private static let folderEventQueue = DispatchQueue(label: "com.borasarang.ApexKey.folderEvents", qos: .utility)
    /// 파일 트리거 콜백 전용 큐 — 폴더 감시 큐와 분리해 해제 순서를 독립적으로 만든다
    private static let fileEventQueue = DispatchQueue(label: "com.borasarang.ApexKey.fileEvents", qos: .utility)
    private var timers: [Timer] = []
    private var lastBatteryLevel: Double = -1
    private var lastChargerConnected: Bool?
    /// timeOfDay 마지막 발동 분 키 — 날짜 포함(yyyy-MM-dd-HH:mm) (P0-4)
    private var activeTimers: [String: String] = [:]
    private let lock = NSLock()
    
    /// 실행 중인 트리거 등록 수
    var registeredCount: Int { registrations.count }
    
    // MARK: - 등록 / 해제
    
    /// 단축어의 모든 트리거 등록
    func register(shortcut: ShortcutItem) {
        for trigger in shortcut.automations {
            register(shortcutID: shortcut.id, shortcutName: shortcut.name, trigger: trigger)
        }
        rebuildWatchers()
    }

    /// 단축어의 모든 트리거 해제
    func unregister(shortcutID: UUID) {
        lock.lock()
        let removed = registrations.filter { $0.shortcutID == shortcutID }
        registrations.removeAll { $0.shortcutID == shortcutID }
        // 세션 가드 딕셔너리 정리 — 삭제된 트리거 키 누적 방지
        for reg in removed {
            activeTimers.removeValue(forKey: reg.trigger.id.uuidString)
        }
        lastFired.removeValue(forKey: shortcutID)
        lock.unlock()
        rebuildWatchers()
    }

    /// 단일 트리거 등록 — 미구현 감시자는 거부 (P1 미구현 8종 무음 방지)
    func register(shortcutID: UUID, shortcutName: String, trigger: AutomationTrigger) {
        guard trigger.isWatcherSupported else {
            Logger.error("E-MAC-AUTO-6001", "미구현 트리거 등록 거부: \(shortcutName) (\(trigger.displayName))")
            return
        }
        lock.lock()
        registrations.append(Registration(shortcutID: shortcutID, shortcutName: shortcutName, trigger: trigger))
        lock.unlock()
    }
    
    /// 모든 트리거 등록 해제
    func unregisterAll() {
        lock.lock()
        registrations.removeAll()
        lock.unlock()
        stopAllWatchers()
    }
    
    // MARK: - 감시자 재구축
    
    private func rebuildWatchers() {
        stopAllWatchers()
        guard !registrations.isEmpty else { return }
        setupTimeWatchers()
        setupFolderWatchers()
        setupFileWatchers()
        setupHardwareWatchers()
        setupExternalDriveWatchers()
        setupDisplayWatchers()
        setupAppWatchers()
    }
    
    private func stopAllWatchers() {
        timers.forEach { $0.invalidate() }
        timers.removeAll()
        releaseStreams(&folderStreams, queues: &folderStreamQueues)
        releaseStreams(&fileStreams, queues: &fileStreamQueues)
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach { center.removeObserver($0) }
        workspaceObservers.removeAll()
        if let displayObserver {
            NotificationCenter.default.removeObserver(displayObserver)
            self.displayObserver = nil
        }
    }

    /// FSEvents 스트림을 콜백 큐의 barrier 뒤에서 해제한다.
    ///
    /// E-MAC-AUTO-8002: 해제 전에 콜백 큐에 barrier를 넣어 in-flight 콜백이 반드시
    /// 반환한 뒤 Release한다. 스트림과 큐를 인덱스째 함께 순회한다.
    private func releaseStreams(_ streams: inout [FSEventStreamRef], queues: inout [DispatchQueue]) {
        let capturedQueues = queues
        for stream in streams {
            FSEventStreamStop(stream)
            FSEventStreamSetDispatchQueue(stream, nil)
        }
        for queue in capturedQueues {
            queue.sync {}
        }
        for stream in streams {
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        streams.removeAll()
        queues.removeAll()
    }
    
    // MARK: - 시간 트리거
    
    private func setupTimeWatchers() {
        lock.lock()
        let timeTriggers = registrations.compactMap { reg -> (Registration, TimeOfDayTrigger)? in
            if case .timeOfDay(let t) = reg.trigger { return (reg, t) }
            return nil
        }
        lock.unlock()
        
        guard !timeTriggers.isEmpty else { return }
        
        // 매 15초마다 시각 확인
        let timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.checkTimeTriggers(timeTriggers)
        }
        timers.append(timer)
        // 즉시 1회 체크
        checkTimeTriggers(timeTriggers)
    }
    
    private func checkTimeTriggers(_ triggers: [(Registration, TimeOfDayTrigger)]) {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)

        for (reg, trigger) in triggers {
            let targetHour = trigger.time.hour ?? 0
            let targetMinute = trigger.time.minute ?? 0
            guard hour == targetHour, minute == targetMinute else { continue }

            // 반복 규칙 확인 (기준 요일/날짜 포함)
            guard trigger.shouldRun(on: now, calendar: calendar) else { continue }

            // 한 번만: 앱 재시작 후에도 재발동 금지 (P0-4/P1)
            if trigger.repeatRule == .none, Self.hasFiredOnce(trigger.id) { continue }

            // 같은 분(날짜 포함) 중복 실행 방지 — "H:M" 키는 다음 날 같은 시각까지 차단하던 버그 (P0-4)
            let key = reg.trigger.id.uuidString
            let dedupKey = Self.timeDedupKey(for: now, calendar: calendar)
            if activeTimers[key] == dedupKey { continue }

            activeTimers[key] = dedupKey
            if trigger.repeatRule == .none {
                Self.markFiredOnce(trigger.id)
            }
            Logger.info("AutomationManager", "시간 트리거 발동: \(reg.shortcutName) (\(trigger.displayName))")
            fire(reg, event: .timeEvent(triggerID: trigger.id))
        }
    }

    /// 날짜가 포함된 분 단위 중복 방지 키 (P0-4)
    nonisolated static func timeDedupKey(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return String(
            format: "%04d-%02d-%02d-%02d:%02d",
            c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0
        )
    }

    private static let firedOnceKeyPrefix = "automation.firedOnce."

    /// repeatRule.none 1회 발동 여부 (UserDefaults 영속)
    nonisolated static func hasFiredOnce(_ triggerID: UUID) -> Bool {
        UserDefaults.standard.bool(forKey: firedOnceKeyPrefix + triggerID.uuidString)
    }

    nonisolated static func markFiredOnce(_ triggerID: UUID) {
        UserDefaults.standard.set(true, forKey: firedOnceKeyPrefix + triggerID.uuidString)
    }
    
    // MARK: - 폴더 트리거 (FSEvents)
    
    private func setupFolderWatchers() {
        lock.lock()
        let folderTriggers = registrations.compactMap { reg -> (Registration, FolderTrigger)? in
            if case .folder(let t) = reg.trigger { return (reg, t) }
            return nil
        }
        lock.unlock()
        
        let grouped = Dictionary(grouping: folderTriggers, by: { $0.1.folderPath })
        for (path, items) in grouped {
            guard items.first != nil else { continue }
            
            let paths = [path]
            var context = FSEventStreamContext(
                version: 0,
                info: Unmanaged.passUnretained(self).toOpaque(),
                retain: nil,
                release: nil,
                copyDescription: nil
            )
            let stream = FSEventStreamCreate(
                kCFAllocatorDefault,
                { _, info, _, eventPaths, eventFlags, _ in
                    guard let info = info else { return }
                    let manager = Unmanaged<AutomationManager>.fromOpaque(info).takeUnretainedValue()
                    let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as? [String] ?? []
                    manager.handleFolderEvent(paths: paths, flags: eventFlags.pointee)
                },
                &context,
                paths as CFArray,
                FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                0.5,
                FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
            )
            
            if let stream = stream {
                folderStreams.append(stream)
                // 콜백이 도는 큐를 보관한다 — stopAllWatchers에서 해제 전에 barrier를 걸어
                // in-flight 콜백이 반드시 반환하도록 한다 (E-MAC-AUTO-8002)
                folderStreamQueues.append(Self.folderEventQueue)
                FSEventStreamSetDispatchQueue(stream, Self.folderEventQueue)
                FSEventStreamStart(stream)
            }
        }
    }
    
    private func handleFolderEvent(paths: [String], flags: FSEventStreamEventFlags) {
        lock.lock()
        let folderTriggers = registrations.compactMap { reg -> (Registration, FolderTrigger)? in
            if case .folder(let t) = reg.trigger { return (reg, t) }
            return nil
        }
        lock.unlock()

        let derivedTypes = Self.folderEventTypes(from: flags)

        for path in paths {
            // 무시 패턴 glob 매치 시 스킵 (P1 ignorePatterns)
            for folderTrigger in folderTriggers {
                guard path.hasPrefix(folderTrigger.1.folderPath) else { continue }
                let parentPath = (path as NSString).deletingLastPathComponent
                guard folderTrigger.1.watchSubfolders || parentPath == folderTrigger.1.folderPath else { continue }
                guard Self.pathMatchesIgnorePatterns(path, patterns: folderTrigger.1.ignorePatterns) == false else { continue }

                // 복합 FSEvent flags에서 트리거가 요청한 타입이 하나라도 있으면 발동 (P1)
                let matched = derivedTypes.filter { folderTrigger.1.eventTypes.contains($0) }
                guard !matched.isEmpty else { continue }

                let url = URL(fileURLWithPath: path)
                for eventType in matched {
                    let event = TriggerEventData.folderEvent(triggerID: folderTrigger.1.id, eventType: eventType, fileURLs: [url])
                    Logger.info("AutomationManager", "폴더 트리거 발동: \(path) (\(eventType.displayName))")
                    fire(folderTrigger.0, event: event)
                }
            }
        }
    }

    /// FSEvent 플래그 → FolderEventType 목록 (복합 flags 전부 산출)
    nonisolated static func folderEventTypes(from flags: FSEventStreamEventFlags) -> [FolderEventType] {
        var types: [FolderEventType] = []
        #if os(macOS)
        if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated) != 0 {
            types.append(.added)
        }
        if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRenamed) != 0 {
            types.append(.renamed)
        }
        if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved) != 0 {
            types.append(.removed)
        }
        if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified) != 0 {
            types.append(.modified)
        }
        #endif
        return types
    }

    /// glob ignorePatterns 매치 — fnmatch(이름 또는 전체 경로)
    nonisolated static func pathMatchesIgnorePatterns(_ path: String, patterns: [String]) -> Bool {
        guard !patterns.isEmpty else { return false }
        let name = (path as NSString).lastPathComponent
        for pattern in patterns {
            if fnmatch(pattern, name, 0) == 0 { return true }
            if fnmatch(pattern, path, 0) == 0 { return true }
        }
        return false
    }
    
    // MARK: - 파일 트리거 (FSEvents, 부모 폴더 감시)

    /// 파일 트리거는 파일이 아니라 **부모 폴더**를 FSEvents로 감시하고, 대상 경로와
    /// 정확히 일치하는 이벤트만 발동한다. FSEvents는 폴더 단위 API이기 때문이다.
    private func setupFileWatchers() {
        lock.lock()
        let fileTriggers = registrations.compactMap { reg -> (Registration, FileTrigger)? in
            if case .file(let t) = reg.trigger { return (reg, t) }
            return nil
        }
        lock.unlock()

        guard !fileTriggers.isEmpty else { return }

        let grouped = Dictionary(grouping: fileTriggers) { item in
            Self.parentDirectory(of: item.1.filePath) ?? ""
        }
        for (directory, items) in grouped {
            guard !directory.isEmpty else {
                Logger.error("E-MAC-AUTO-8004", "파일 트리거 경로 없음: \(items.count)개 무시")
                continue
            }
            guard FileManager.default.fileExists(atPath: directory) else {
                Logger.error("E-MAC-AUTO-8004", "파일 트리거 부모 폴더 없음: \(directory)")
                continue
            }

            var context = FSEventStreamContext(
                version: 0,
                info: Unmanaged.passUnretained(self).toOpaque(),
                retain: nil,
                release: nil,
                copyDescription: nil
            )
            let stream = FSEventStreamCreate(
                kCFAllocatorDefault,
                { _, info, _, eventPaths, _, _ in
                    guard let info = info else { return }
                    let manager = Unmanaged<AutomationManager>.fromOpaque(info).takeUnretainedValue()
                    let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as? [String] ?? []
                    manager.handleFileEvent(paths: paths)
                },
                &context,
                [directory] as CFArray,
                FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                0.5,
                FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
            )

            if let stream {
                fileStreams.append(stream)
                fileStreamQueues.append(Self.fileEventQueue)
                FSEventStreamSetDispatchQueue(stream, Self.fileEventQueue)
                FSEventStreamStart(stream)
            }
        }
    }

    private func handleFileEvent(paths: [String]) {
        lock.lock()
        let fileTriggers = registrations.compactMap { reg -> (Registration, FileTrigger)? in
            if case .file(let t) = reg.trigger { return (reg, t) }
            return nil
        }
        lock.unlock()

        for path in paths {
            let normalized = Self.normalizedPath(path)
            for (reg, trigger) in fileTriggers {
                let target = Self.normalizedPath(trigger.filePath)
                guard !target.isEmpty, normalized == target else { continue }
                Logger.info("AutomationManager", "파일 트리거 발동: \(path)")
                fire(reg, event: .fileEvent(triggerID: trigger.id, fileURL: URL(fileURLWithPath: path)))
            }
        }
    }

    /// 파일 경로를 절대·표준 경로로 정규화한다 (`~` 확장 포함)
    nonisolated static func normalizedPath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath)
            .standardizedFileURL
            .path
    }

    /// 파일 트리거가 감시할 부모 폴더 경로
    nonisolated static func parentDirectory(of filePath: String) -> String? {
        let normalized = normalizedPath(filePath)
        guard !normalized.isEmpty else { return nil }
        return URL(fileURLWithPath: normalized).deletingLastPathComponent().path
    }

    // MARK: - 외장 드라이브 트리거

    private func setupExternalDriveWatchers() {
        lock.lock()
        let driveTriggers = registrations.compactMap { reg -> (Registration, ExternalDriveTrigger)? in
            if case .externalDrive(let t) = reg.trigger { return (reg, t) }
            return nil
        }
        lock.unlock()

        guard !driveTriggers.isEmpty else { return }

        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification] {
            let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                self?.handleDriveNotification(note)
            }
            workspaceObservers.append(observer)
        }
    }

    private func handleDriveNotification(_ note: Notification) {
        guard let eventType = Self.driveEventType(forNotification: note.name) else { return }
        guard let url = note.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else { return }
        let driveName = url.lastPathComponent

        lock.lock()
        let driveTriggers = registrations.compactMap { reg -> (Registration, ExternalDriveTrigger)? in
            if case .externalDrive(let t) = reg.trigger { return (reg, t) }
            return nil
        }
        lock.unlock()

        for (reg, trigger) in driveTriggers {
            if let wanted = trigger.driveName,
               !wanted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               wanted != driveName {
                continue
            }
            guard trigger.eventTypes.contains(eventType) else { continue }
            Logger.info("AutomationManager", "외장 드라이브 트리거 발동: \(driveName) (\(eventType.displayName))")
            fire(
                reg,
                event: .driveEvent(
                    triggerID: trigger.id,
                    eventType: eventType,
                    driveName: driveName,
                    mountPoint: url.path
                )
            )
        }
    }

    nonisolated static func driveEventType(forNotification name: Notification.Name) -> DriveEventType? {
        if name == NSWorkspace.didMountNotification { return .mounted }
        if name == NSWorkspace.didUnmountNotification { return .unmounted }
        return nil
    }

    // MARK: - 디스플레이 트리거

    private func setupDisplayWatchers() {
        lock.lock()
        let displayTriggers = registrations.compactMap { reg -> (Registration, DisplayTrigger)? in
            if case .display(let t) = reg.trigger { return (reg, t) }
            return nil
        }
        lock.unlock()

        guard !displayTriggers.isEmpty else { return }

        lastDisplayCount = NSScreen.screens.count
        displayObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleDisplayChange()
        }
    }

    private func handleDisplayChange() {
        let current = NSScreen.screens.count
        let previous = lastDisplayCount
        lastDisplayCount = current
        let types = Self.displayEventTypes(previousCount: previous, currentCount: current)
        guard !types.isEmpty else { return }

        lock.lock()
        let displayTriggers = registrations.compactMap { reg -> (Registration, DisplayTrigger)? in
            if case .display(let t) = reg.trigger { return (reg, t) }
            return nil
        }
        lock.unlock()

        for (reg, trigger) in displayTriggers {
            for type in types where trigger.eventTypes.contains(type) {
                Logger.info("AutomationManager", "디스플레이 트리거 발동: \(type.displayName)")
                fire(
                    reg,
                    event: .displayEvent(
                        triggerID: trigger.id,
                        eventType: type,
                        screenCount: current
                    )
                )
            }
        }
    }

    /// 화면 수 변화로 연결/분리를 판정한다. 해상도·배치만 바뀐 경우는 발동하지 않는다.
    nonisolated static func displayEventTypes(previousCount: Int, currentCount: Int) -> [DisplayEventType] {
        if currentCount > previousCount { return [.connected] }
        if currentCount < previousCount { return [.disconnected] }
        return []
    }

    // MARK: - 앱 트리거

    private func setupAppWatchers() {
        lock.lock()
        let appTriggers = registrations.compactMap { reg -> (Registration, AppTrigger)? in
            if case .app(let t) = reg.trigger { return (reg, t) }
            return nil
        }
        lock.unlock()

        guard !appTriggers.isEmpty else { return }

        let center = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didDeactivateApplicationNotification,
        ]
        for name in names {
            let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                self?.handleAppNotification(note)
            }
            workspaceObservers.append(observer)
        }
    }

    private func handleAppNotification(_ note: Notification) {
        guard let eventType = Self.appEventType(forNotification: note.name) else { return }
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleID = app.bundleIdentifier else { return }

        lock.lock()
        let appTriggers = registrations.compactMap { reg -> (Registration, AppTrigger)? in
            if case .app(let t) = reg.trigger { return (reg, t) }
            return nil
        }
        lock.unlock()

        for (reg, trigger) in appTriggers {
            guard trigger.bundleID == bundleID else { continue }
            guard trigger.eventTypes.contains(eventType) else { continue }
            Logger.info("AutomationManager", "앱 트리거 발동: \(bundleID) (\(eventType.displayName))")
            fire(reg, event: .appEvent(triggerID: trigger.id, eventType: eventType, bundleID: bundleID))
        }
    }

    nonisolated static func appEventType(forNotification name: Notification.Name) -> AppEventType? {
        if name == NSWorkspace.didLaunchApplicationNotification { return .launched }
        if name == NSWorkspace.didTerminateApplicationNotification { return .terminated }
        if name == NSWorkspace.didActivateApplicationNotification { return .activated }
        if name == NSWorkspace.didDeactivateApplicationNotification { return .deactivated }
        return nil
    }

    // MARK: - 하드웨어/배터리/충전기 트리거
    
    private func setupHardwareWatchers() {
        lock.lock()
        let hasBatteryOrCharger = registrations.contains {
            if case .battery = $0.trigger { return true }
            if case .charger = $0.trigger { return true }
            return false
        }
        lock.unlock()
        
        guard hasBatteryOrCharger else { return }
        
        lastBatteryLevel = VariableResolver.batteryLevel()
        lastChargerConnected = isChargerConnected()
        
        let timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkBatteryAndCharger()
        }
        timers.append(timer)
    }
    
    private func checkBatteryAndCharger() {
        let battery = VariableResolver.batteryLevel()
        
        lock.lock()
        let batteryRegs = registrations.compactMap { reg -> (Registration, BatteryTrigger)? in
            if case .battery(let t) = reg.trigger { return (reg, t) }
            return nil
        }
        let chargerRegs = registrations.compactMap { reg -> (Registration, ChargerTrigger)? in
            if case .charger(let t) = reg.trigger { return (reg, t) }
            return nil
        }
        lock.unlock()
        
        // 배터리 트리거 확인
        for (reg, trigger) in batteryRegs {
            let threshold = trigger.threshold
            let crossed: Bool
            switch trigger.condition {
            case .fallsBelow:
                crossed = lastBatteryLevel > threshold && battery <= threshold
            case .risesAbove:
                crossed = lastBatteryLevel < threshold && battery >= threshold
            case .reaches:
                crossed = lastBatteryLevel != threshold && battery == threshold
            }
            if crossed {
                Logger.info("AutomationManager", "배터리 트리거 발동: \(trigger.displayName)")
                let event = TriggerEventData(triggerID: trigger.id, triggerType: "battery", timestamp: Date(),
                                             data: ["level": .number(battery)])
                fire(reg, event: event)
            }
        }
        
        // 충전기 트리거 확인 — 연결/해제 각각 독립 평가 (한 트리거에 둘 다 지정 가능)
        let chargerNow = isChargerConnected()
        for (reg, trigger) in chargerRegs {
            guard let last = lastChargerConnected else { continue }

            // 연결 이벤트: 이전에 해제 → 현재 연결 상태로 전환
            if trigger.eventTypes.contains(.connected) && !last && chargerNow {
                fireChargerTrigger(reg, trigger: trigger, connected: true)
            }
            // 해제 이벤트: 이전에 연결 → 현재 해제 상태로 전환
            if trigger.eventTypes.contains(.disconnected) && last && !chargerNow {
                fireChargerTrigger(reg, trigger: trigger, connected: false)
            }
        }
        
        lastBatteryLevel = battery
        lastChargerConnected = chargerNow
    }

    private func fireChargerTrigger(_ reg: Registration, trigger: ChargerTrigger, connected: Bool) {
        let eventType: ChargerEventType = connected ? .connected : .disconnected
        Logger.info("AutomationManager", "충전기 트리거 발동: \(trigger.displayName) (\(eventType.displayName))")
        let event = TriggerEventData(triggerID: trigger.id, triggerType: "charger", timestamp: Date(),
                                     data: ["connected": .boolean(connected)])
        fire(reg, event: event)
    }
    
    private func isChargerConnected() -> Bool {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            // 배터리/전원 정보를 읽을 수 없는 환경(데스크톱 등)에서는 충전 중으로 간주하지 않음
            return false
        }
        let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [Any] ?? []
        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(blob, source as CFTypeRef)?.takeUnretainedValue() as? [String: Any] else { continue }
            if let powered = desc[kIOPSPowerSourceStateKey] as? String, powered == kIOPSACPowerValue {
                return true
            }
        }
        return false
    }
    
    // MARK: - 트리거 발동
    
    private func fire(_ reg: Registration, event: TriggerEventData) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // 디바운스: 같은 단축어를 3초 내 재발동 방지
            guard !isRecentlyFired(reg.shortcutID) else { return }
            Logger.info("AutomationManager", "트리거 실행: \(reg.shortcutName)")
            onTriggerFired?(reg.shortcutID, reg.trigger, event)
        }
    }
    
    private var lastFired: [UUID: Date] = [:]
    private func isRecentlyFired(_ shortcutID: UUID) -> Bool {
        let now = Date()
        if let last = lastFired[shortcutID], now.timeIntervalSince(last) < 3 {
            return true
        }
        lastFired[shortcutID] = now
        return false
    }
}
