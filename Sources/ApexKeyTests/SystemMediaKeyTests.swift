import XCTest
@testable import ApexKey

/// 시스템 미디어 키 이벤트 인코딩 — IOKit `NX_SYSDEFINED` 규격.
///
/// 실제 키 주입은 시스템 볼륨·HUD를 건드리므로 단위 테스트에서 실행하지 않는다.
/// 주입 경로는 실기 확인(사용자 단축키)으로 검증한다.
final class SystemMediaKeyTests: XCTestCase {
    func testKeyCodesMatchIOKitConstants() {
        XCTAssertEqual(SystemMediaKey.soundUp.rawValue, 0)
        XCTAssertEqual(SystemMediaKey.soundDown.rawValue, 1)
        XCTAssertEqual(SystemMediaKey.mute.rawValue, 7)
        XCTAssertEqual(SystemMediaKey.subtype, 8)
    }

    func testData1EncodesKeyAndState() {
        // (key << 16) | (state << 8)
        XCTAssertEqual(SystemMediaKey.data1(key: 0, isDown: true), 0x0000_0A00)
        XCTAssertEqual(SystemMediaKey.data1(key: 0, isDown: false), 0x0000_0B00)
        XCTAssertEqual(SystemMediaKey.data1(key: 1, isDown: true), 0x0001_0A00)
        XCTAssertEqual(SystemMediaKey.data1(key: 7, isDown: true), 0x0007_0A00)
        XCTAssertEqual(SystemMediaKey.data1(key: 7, isDown: false), 0x0007_0B00)
    }

    func testData1SeparatesKeyFromState() {
        for key in SystemMediaKey.allCases {
            let down = SystemMediaKey.data1(key: key.rawValue, isDown: true)
            let up = SystemMediaKey.data1(key: key.rawValue, isDown: false)
            XCTAssertEqual(down >> 16, Int(key.rawValue))
            XCTAssertEqual((down >> 8) & 0xFF, 0x0A)
            XCTAssertEqual((up >> 8) & 0xFF, 0x0B)
            // 상태 비트만 다르다 — 키 비트는 그대로
            XCTAssertEqual(down ^ up, 0x0100)
        }
    }
}
