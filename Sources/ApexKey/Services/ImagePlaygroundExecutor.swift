import Foundation
import AppKit

/// 이미지 플레이그라운드 액션 실행기
final class ImagePlaygroundExecutor {
    static let shared = ImagePlaygroundExecutor()
    
    private let availabilityManager = AIAvailabilityManager.shared
    
    /// 이미지 플레이그라운드 실행
    @discardableResult
    func execute(_ step: ShortcutStep, context: inout UseModelExecutor.ExecutionContext) -> Bool {
        guard let playground = step.imagePlayground else {
            Logger.error("E-MAC-AI-9020", "ImagePlaygroundExecutor: step에 imagePlayground 설정이 없음")
            return false
        }
        
        Logger.info("ImagePlaygroundExecutor", "실행 시작: \(playground.displayName)")
        
        // 가용성 체크
        let availability = availabilityManager.isAvailable(.onDevice)
        guard availability.isAvailable else {
            Logger.error("E-MAC-AI-9020", "이미지 플레이그라운드 사용 불가: \(availability.displayMessage)")
            return false
        }
        
        // macOS 26+에서 FoundationModels 실행
        if #available(macOS 26.0, *) {
            return executeWithFoundationModels(
                playground: playground,
                context: &context
            )
        } else {
            Logger.error("E-MAC-AI-9022", "Apple Intelligence 사용 불가")
            return false
        }
    }
    
    // MARK: - FoundationModels (macOS 26+)
    
    @available(macOS 26.0, *)
    private func executeWithFoundationModels(
        playground: ImagePlaygroundStep,
        context: inout UseModelExecutor.ExecutionContext
    ) -> Bool {
        // E-MAC-AI-9013: ImagePlayground 프레임워크 연동이 아직 구현되지 않았다.
        // 이전 구현은 512×512 단색 사각형에 프롬프트를 그린 플레이스홀더 이미지를
        // "이미지 생성 완료"로 로그하고 `return true`를 해 성공으로 보고했다.
        // 임시 디렉터리에 파일을 남기는 부작용도 함께 제거한다.
        //
        // TODO(PLAN_v0.21 T-143 후속):
        // 1. ImagePlayground() 세션 생성
        // 2. 프롬프트 + 스타일 설정
        // 3. 이미지 생성 요청
        // 4. 생성된 이미지를 변수에 저장
        Logger.error("E-MAC-AI-9013", "ImagePlayground 연동 미구현 — 이미지 생성 단계 실패 처리: \(playground.style.displayName)")
        return false
    }

    // MARK: - 플레이스홀더 이미지 생성 (미구현 상태에서는 호출되지 않음)
    //
    // E-MAC-AI-9013에서 실행 경로에서 제거했다. "이미지 생성"으로 오인될 수 있어
    // 후속 AI 구현 시에는 재생성하지 않는다.

    /// 단색 + 텍스트 플레이스홀더 — **실제 생성 이미지가 아니므로 AI 단계에서 사용 금지**
    private func createPlaceholderImage(prompt: String, style: ImagePlaygroundStyle) -> NSImage? {
        let size = NSSize(width: 512, height: 512)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // 배경색
        let bgColor: NSColor
        switch style {
        case .animation: bgColor = NSColor(calibratedHue: 0.6, saturation: 0.6, brightness: 0.9, alpha: 1.0)
        case .illustration: bgColor = NSColor(calibratedHue: 0.3, saturation: 0.5, brightness: 0.85, alpha: 1.0)
        case .sketch: bgColor = NSColor(calibratedWhite: 0.95, alpha: 1.0)
        }
        bgColor.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // 텍스트 표시
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .medium),
            .foregroundColor: NSColor.white,
            .paragraphStyle: {
                let ps = NSMutableParagraphStyle()
                ps.alignment = .center
                return ps
            }()
        ]
        
        let displayText = prompt.isEmpty ? "ai.image.placeholder_fmt".localizedFormat(style.displayName) : prompt
        let attributedString = NSAttributedString(string: displayText, attributes: attrs)
        let textRect = NSRect(x: 20, y: size.height / 2 - 20, width: size.width - 40, height: 40)
        attributedString.draw(in: textRect)
        
        // 스타일 라벨
        let styleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.white.withAlphaComponent(0.7),
        ]
        let styleText = NSAttributedString(string: "ai.image.badge_fmt".localizedFormat(style.displayName), attributes: styleAttrs)
        styleText.draw(at: NSPoint(x: 20, y: 20))
        
        image.unlockFocus()
        
        return image
    }
}
