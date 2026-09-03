import Foundation
import ApplicationServices

/// Accessibility 권한 유틸리티
enum PermissionHelper {
    /// Accessibility(손쉬운 사용) 권한이 부여되었는지
    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// 권한 요청 (시스템 설정 열기)
    static func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
