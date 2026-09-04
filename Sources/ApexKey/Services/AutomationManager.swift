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
    private var timers: [Timer] = []
    private var lastBatteryLevel: Double = -1
    private var lastChargerConnected: Bool?
    private var activeTimers: [String: String] = [:]  // timeOfDay 마지막 실행 분 키("HH:MM")
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
        defer { lock.unlock() }
        registrations.removeAll { $0.shortcutID == shortcutID }
        rebuildWatchers()
    }
    
    /// 단일 트리거 등록
    func register(shortcutID: UUID, shortcutName: String, trigger: AutomationTrigger) {
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
    
    /// 감시 중단 (앱 종료)
    func stopAll() {
        unregisterAll()
    }
    
    // MARK: - 감시자 재구축
    
    private func rebuildWatchers() {
        stopAllWatchers()
        guard !registrations.isEmpty else { return }
        setupTimeWatchers()
        setupFolderWatchers()
        setupHardwareWatchers()
    }
    
    private func stopAllWatchers() {
        timers.forEach { $0.invalidate() }
        timers.removeAll()
        for stream in folderStreams {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        folderStreams.removeAll()
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
            
            // 반복 규칙 확인
            guard trigger.repeatRule.shouldRun(on: now) else { continue }
            
            // 같은 분에 중복 실행 방지
            let key = reg.trigger.id.uuidString
            let minuteKey = "\(hour):\(minute)"
            if activeTimers[key] == minuteKey {
                continue
            }
            
            activeTimers[key] = minuteKey
            Logger.info("AutomationManager", "시간 트리거 발동: \(reg.shortcutName) (\(trigger.displayName))")
            fire(reg, event: .timeEvent(triggerID: trigger.id))
        }
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
                FSEventStreamSetDispatchQueue(stream, DispatchQueue.global(qos: .utility))
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

        let derivedEventType = Self.folderEventType(from: flags)

        for path in paths {
            let parentPath = (path as NSString).deletingLastPathComponent
            for folderTrigger in folderTriggers where
                path.hasPrefix(folderTrigger.1.folderPath) &&
                (folderTrigger.1.watchSubfolders || (parentPath == folderTrigger.1.folderPath)) {
                // 트리거가 감시 중인 이벤트 타입인지 확인
                guard let eventType = derivedEventType,
                      folderTrigger.1.eventTypes.contains(eventType) else { continue }

                let url = URL(fileURLWithPath: path)
                let event = TriggerEventData.folderEvent(triggerID: folderTrigger.1.id, eventType: eventType, fileURLs: [url])
                Logger.info("AutomationManager", "폴더 트리거 발동: \(path) (\(eventType.displayName))")
                fire(folderTrigger.0, event: event)
            }
        }
    }

    /// FSEvent 플래그 → FolderEventType 매핑
    private static func folderEventType(from flags: FSEventStreamEventFlags) -> FolderEventType? {
        #if os(macOS)
        if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated) != 0 {
            return .added
        }
        if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRenamed) != 0 {
            return .renamed
        }
        if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved) != 0 {
            return .removed
        }
        if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified) != 0 {
            return .modified
        }
        #endif
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
