import Foundation
import AppKit
import Vision

/// 이미지 인식 액션 (T-211) — 텍스트 OCR · QR · 동물 인식
///
/// 입력은 **파일 경로 또는 클립보드 이미지**다. 경로를 지정했는데 파일이 없으면
/// 클립보드로 몰래 폴백하지 않는다 — 사용자가 지정한 입력이 없다는 사실을
/// 실패로 알려야 "왜 엉뚱한 결과가 나왔지"를 막을 수 있다.
enum VisionActions {

    enum Outcome: Equatable {
        case success(String)
        case failure(FailureReason)

        var text: String {
            switch self {
            case .success(let value): return value
            case .failure: return ""
            }
        }

        var isSuccess: Bool {
            if case .success = self { return true }
            return false
        }
    }

    enum FailureReason: Equatable, Error {
        case noImage
        case noText
        case noCode
        case noAnimal
        case requestFailed(String)

        var messageKey: String {
            switch self {
            case .noImage: return "error.user.next_image_missing"
            case .noText: return "error.user.next_text_missing"
            case .noCode: return "error.user.next_code_missing"
            case .noAnimal: return "error.user.next_animal_missing"
            case .requestFailed: return "error.user.next_vision_failed"
            }
        }
    }

    /// 입력 이미지 데이터를 읽는다.
    ///
    /// - Parameter path: 파일 경로. 비어 있으면 클립보드 이미지를 쓴다.
    /// - Returns: 읽지 못하면 nil (경로 지정 시 클립보드 폴백 없음)
    static func imageData(from path: String?) -> Data? {
        let trimmed = (path ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let expanded = (trimmed as NSString).expandingTildeInPath
            return try? Data(contentsOf: URL(fileURLWithPath: expanded))
        }
        let pasteboard = NSPasteboard.general
        if let png = pasteboard.data(forType: .png) { return png }
        if let tiff = pasteboard.data(forType: .tiff) { return tiff }
        return nil
    }

    /// 이미지에서 텍스트를 인식한다 (줄바꿈으로 연결)
    static func recognizeText(imageData: Data?) -> Outcome {
        guard let data = imageData else { return .failure(.noImage) }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        switch perform([request], on: data) {
        case .failure(let reason):
            return .failure(reason)
        case .success:
            let lines = (request.results ?? []).compactMap {
                $0.topCandidates(1).first?.string
            }
            guard !lines.isEmpty else { return .failure(.noText) }
            return .success(lines.joined(separator: "\n"))
        }
    }

    /// 이미지에서 QR/바코드 문자열을 읽는다 (여러 개면 줄바꿈)
    static func scanQRCode(imageData: Data?) -> Outcome {
        guard let data = imageData else { return .failure(.noImage) }
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]

        switch perform([request], on: data) {
        case .failure(let reason):
            return .failure(reason)
        case .success:
            let codes = (request.results ?? []).compactMap { $0.payloadStringValue }
            guard !codes.isEmpty else { return .failure(.noCode) }
            return .success(codes.joined(separator: "\n"))
        }
    }

    /// 이미지에서 동물을 인식한다 (라벨 + 신뢰도)
    static func recognizeAnimal(imageData: Data?) -> Outcome {
        guard let data = imageData else { return .failure(.noImage) }
        let request = VNRecognizeAnimalsRequest()

        switch perform([request], on: data) {
        case .failure(let reason):
            return .failure(reason)
        case .success:
            let observations = request.results ?? []
            var lines: [String] = []
            for observation in observations {
                for label in observation.labels {
                    let percent = Int((label.confidence * 100).rounded())
                    lines.append("\(label.identifier) (\(percent)%)")
                }
            }
            guard !lines.isEmpty else { return .failure(.noAnimal) }
            return .success(lines.joined(separator: "\n"))
        }
    }

    // MARK: - 내부

    private static func perform(
        _ requests: [VNRequest],
        on data: Data
    ) -> Result<Void, FailureReason> {
        guard let image = NSImage(data: data),
              let cgImage = image.cgImage(
                forProposedRect: nil,
                context: nil,
                hints: nil
              ) else {
            return .failure(.noImage)
        }
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform(requests)
            return .success(())
        } catch {
            return .failure(.requestFailed(error.localizedDescription))
        }
    }
}
