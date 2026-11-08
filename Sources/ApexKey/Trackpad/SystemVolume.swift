import Foundation
import CoreAudio
import AudioToolbox

/// 시스템 출력 볼륨 읽기/쓰기 — CoreAudio 직접 제어.
///
/// AppleScript(`set volume output volume`)는 호출마다 60~120ms가 걸려
/// 연속 슬라이더에 쓸 수 없다. 여기서는 기본 출력 장치의 스칼라 볼륨을
/// 직접 읽고 쓴다(스파이크 실측: 읽기·쓰기 status 0).
///
/// 스레드: `AudioObjectGet/SetPropertyData`는 스레드 안전이므로
/// 트랙패드 콜백 스레드에서 바로 호출해도 된다.
enum SystemVolume {
    // 'vmvc' — 가상 메인 볼륨. 대부분의 출력 장치가 지원한다.
    private static let virtualMainVolume = AudioObjectPropertySelector(0x766D7663)
    private static let mainElement = AudioObjectPropertyElement(0)

    private static var defaultOutputDevice: AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device
        )
        guard status == noErr, device != 0 else { return nil }
        return device
    }

    /// 현재 볼륨 0.0 ... 1.0
    static func current() -> Float? {
        guard let device = defaultOutputDevice else { return nil }
        if let v = readVolume(device: device, selector: virtualMainVolume, element: mainElement) {
            return v
        }
        // 폴백: 채널별 스칼라 (구형/일부 USB DAC)
        if let l = readVolume(device: device, selector: kAudioDevicePropertyVolumeScalar, element: 1) {
            let r = readVolume(device: device, selector: kAudioDevicePropertyVolumeScalar, element: 2) ?? l
            return (l + r) / 2
        }
        return nil
    }

    /// 볼륨 설정. 성공하면 true.
    @discardableResult
    static func set(_ value: Float) -> Bool {
        guard let device = defaultOutputDevice else { return false }
        let clamped = min(max(value, 0), 1)
        if writeVolume(device: device, selector: virtualMainVolume, element: mainElement, value: clamped) {
            return true
        }
        let left = writeVolume(device: device, selector: kAudioDevicePropertyVolumeScalar, element: 1, value: clamped)
        let right = writeVolume(device: device, selector: kAudioDevicePropertyVolumeScalar, element: 2, value: clamped)
        return left || right
    }

    /// 증분 조절. 새 볼륨을 반환한다(실패 시 nil).
    @discardableResult
    static func adjust(by delta: Float) -> Float? {
        guard let now = current() else { return nil }
        let next = min(max(now + delta, 0), 1)
        // 1% 미만 변화는 무시 — 슬라이더 미세 떨림으로 인한 과호출 방지
        guard abs(next - now) >= 0.01 else { return now }
        guard set(next) else { return nil }
        return next
    }

    static var isMuted: Bool? {
        guard let device = defaultOutputDevice else { return nil }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: mainElement
        )
        guard AudioObjectHasProperty(device, &address) else { return nil }
        var value = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value != 0
    }

    // MARK: - 저수준

    private static func readVolume(
        device: AudioDeviceID,
        selector: AudioObjectPropertySelector,
        element: AudioObjectPropertyElement
    ) -> Float? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
        guard AudioObjectHasProperty(device, &address) else { return nil }
        var value = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value)
        guard status == noErr, value.isFinite else { return nil }
        return min(max(value, 0), 1)
    }

    @discardableResult
    private static func writeVolume(
        device: AudioDeviceID,
        selector: AudioObjectPropertySelector,
        element: AudioObjectPropertyElement,
        value: Float
    ) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
        guard AudioObjectHasProperty(device, &address) else { return false }
        var settable = DarwinBoolean(false)
        guard AudioObjectIsPropertySettable(device, &address, &settable) == noErr, settable.boolValue else {
            return false
        }
        var v = Float32(value)
        let size = UInt32(MemoryLayout<Float32>.size)
        return AudioObjectSetPropertyData(device, &address, 0, nil, size, &v) == noErr
    }
}
