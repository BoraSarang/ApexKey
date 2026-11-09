import AVFoundation
import Foundation

/// 카메라 사진 촬영 (T-220)
///
/// AVFoundation으로 기본 비디오 장치에서 한 장을 촬영해 파일로 저장한다.
/// 카메라 권한은 첫 실행 시 macOS가 한 번 요청한다(`NSCameraUsageDescription`).
/// 권한이 거부되었거나 카메라가 없으면 사유를 구분해 돌려준다.
enum CameraCapture {

    enum Failure: Error, Equatable {
        case denied
        case unavailable
        case failed(String)
    }

    /// 동기 API — 호출 스레드를 최대 `timeout`초까지 기다린다.
    /// UI 메인 스레드에서 부르지 않도록 엔진에서 백그라운드 실행을 권장한다.
    static func capture(to url: URL, timeout: TimeInterval = 15) -> Result<Void, Failure> {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            let semaphore = DispatchSemaphore(value: 0)
            var granted = false
            AVCaptureDevice.requestAccess(for: .video) { access in
                granted = access
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: .now() + timeout)
            guard granted else { return .failure(.denied) }
        case .denied, .restricted:
            return .failure(.denied)
        @unknown default:
            return .failure(.denied)
        }

        guard let device = AVCaptureDevice.default(for: .video) else {
            return .failure(.unavailable)
        }

        let session = AVCaptureSession()
        guard let input = try? AVCaptureDeviceInput(device: device) else {
            return .failure(.failed("camera input could not be created"))
        }
        let output = AVCapturePhotoOutput()

        session.beginConfiguration()
        guard session.canAddInput(input), session.canAddOutput(output) else {
            session.commitConfiguration()
            return .failure(.failed("camera session configuration failed"))
        }
        session.addInput(input)
        session.addOutput(output)
        session.commitConfiguration()

        let delegate = PhotoDelegate(destination: url)
        session.startRunning()
        output.capturePhoto(with: AVCapturePhotoSettings(), delegate: delegate)
        let finished = delegate.wait(timeout: timeout)
        session.stopRunning()

        guard finished else { return .failure(.failed("camera capture timed out")) }
        return delegate.result
    }

    private final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
        private let destination: URL
        private let semaphore = DispatchSemaphore(value: 0)
        private let lock = NSLock()
        private(set) var result: Result<Void, Failure> = .failure(.failed("camera capture did not finish"))

        init(destination: URL) {
            self.destination = destination
        }

        func wait(timeout: TimeInterval) -> Bool {
            semaphore.wait(timeout: .now() + timeout) == .success
        }

        func photoOutput(
            _ output: AVCapturePhotoOutput,
            didFinishProcessingPhoto photo: AVCapturePhoto,
            error: Error?
        ) {
            lock.lock()
            defer { lock.unlock() }

            if let error {
                result = .failure(.failed(error.localizedDescription))
            } else if let data = photo.fileDataRepresentation() {
                do {
                    try data.write(to: destination, options: .atomic)
                    result = .success(())
                } catch {
                    result = .failure(.failed(error.localizedDescription))
                }
            } else {
                result = .failure(.failed("camera returned no data"))
            }
            semaphore.signal()
        }
    }
}
