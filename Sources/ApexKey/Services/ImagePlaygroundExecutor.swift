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
        Logger.info("ImagePlaygroundExecutor", "FoundationModels 실행: \(playground.style.displayName)")
        
        // TODO: ImagePlayground 프레임워크 실제 연동
        // Apple Shortcuts에서의 ImagePlayground 흐름:
        // 1. ImagePlayground() 세션 생성
        // 2. 프롬프트 + 스타일 설정
        // 3. 이미지 생성 요청
        // 4. 생성된 이미지를 변수에 저장
        
        // 임시: 플레이스홀더 이미지 생성
        let placeholderImage = createPlaceholderImage(
            prompt: playground.prompt,
            style: playground.style
        )
        
        if let imageData = placeholderImage?.tiffRepresentation {
            // 이미지를 파일로 저장하고 경로를 변수로
            let tempDir = FileManager.default.temporaryDirectory
            let imageURL = tempDir.appendingPathComponent("apexkey_img_\(UUID().uuidString.prefix(8)).png")
            if let bitmap = NSBitmapImageRep(data: imageData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try? pngData.write(to: imageURL)
                context.setOutput(.file(imageURL), for: playground.outputVariable)
                Logger.info("ImagePlaygroundExecutor", "이미지 생성 완료: \(imageURL.lastPathComponent)")
            }
        } else {
            context.setOutput(.null, for: playground.outputVariable)
        }
        
        Logger.info("ImagePlaygroundExecutor", "실행 완료")
        return true
    }
    
    // MARK: - 플레이스홀더 이미지 생성
    
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
        
        let displayText = prompt.isEmpty ? "이미지 생성\n(\(style.displayName))" : prompt
        let attributedString = NSAttributedString(string: displayText, attributes: attrs)
        let textRect = NSRect(x: 20, y: size.height / 2 - 20, width: size.width - 40, height: 40)
        attributedString.draw(in: textRect)
        
        // 스타일 라벨
        let styleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.white.withAlphaComponent(0.7),
        ]
        let styleText = NSAttributedString(string: "ImagePlayground - \(style.displayName)", attributes: styleAttrs)
        styleText.draw(at: NSPoint(x: 20, y: 20))
        
        image.unlockFocus()
        
        return image
    }
}
