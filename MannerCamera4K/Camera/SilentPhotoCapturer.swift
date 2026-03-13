import AVFoundation
import Photos

final class SilentPhotoCapturer: NSObject {

    private let photoOutput: AVCapturePhotoOutput
    private let settings: CameraSettings
    private let currentDevice: AVCaptureDevice?
    private let currentLens: LensType
    private let cameraPosition: AVCaptureDevice.Position
    private var continuation: CheckedContinuation<Void, Error>?

    init(
        photoOutput: AVCapturePhotoOutput,
        settings: CameraSettings,
        currentDevice: AVCaptureDevice?,
        currentLens: LensType,
        cameraPosition: AVCaptureDevice.Position
    ) {
        self.photoOutput = photoOutput
        self.settings = settings
        self.currentDevice = currentDevice
        self.currentLens = currentLens
        self.cameraPosition = cameraPosition
    }

    func capturePhoto(flashEnabled: Bool, nightMode: Bool) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let photoSettings = createPhotoSettings(flashEnabled: flashEnabled)
            configureSilentMode(photoSettings)

            photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }

    private func createPhotoSettings(flashEnabled: Bool) -> AVCapturePhotoSettings {
        let photoSettings: AVCapturePhotoSettings

        if settings.photoFormat == .heif {
            photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        } else {
            photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        }

        if flashEnabled && photoOutput.supportedFlashModes.contains(.on) {
            photoSettings.flashMode = .on
        }

        // 最大解像度（48MPは広角レンズ+バックカメラのみ）
        if let device = currentDevice {
            if settings.photoResolution == .high
                && currentLens == .wide
                && cameraPosition == .back {
                let maxDim = DeviceCapability.maxPhotoDimensions(for: device)
                photoSettings.maxPhotoDimensions = maxDim
            }
        }

        photoSettings.photoQualityPrioritization = .quality

        return photoSettings
    }

    private func configureSilentMode(_ photoSettings: AVCapturePhotoSettings) {
        // 方式1: 公式API（iOS 18+）
        if #available(iOS 18.0, *) {
            if photoOutput.isShutterSoundSuppressionSupported {
                photoSettings.isShutterSoundSuppressionEnabled = true
                return
            }
        }

        // 方式2: Live Photos を有効化してシャッター音を抑制
        if photoOutput.isLivePhotoCaptureSupported {
            photoOutput.isLivePhotoCaptureEnabled = true
            let livePhotoURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")
            photoSettings.livePhotoMovieFileURL = livePhotoURL
        }
    }
}

extension SilentPhotoCapturer: AVCapturePhotoCaptureDelegate {

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            continuation?.resume(throwing: error)
            continuation = nil
            return
        }

        guard let imageData = photo.fileDataRepresentation() else {
            continuation?.resume(throwing: CaptureError.noImageData)
            continuation = nil
            return
        }

        Task {
            do {
                try await PhotoLibraryManager.savePhoto(imageData)
                continuation?.resume()
            } catch {
                continuation?.resume(throwing: error)
            }
            continuation = nil
        }
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL,
        duration: CMTime,
        photoDisplayTime: CMTime,
        resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        try? FileManager.default.removeItem(at: outputFileURL)
    }
}

enum CaptureError: LocalizedError {
    case noImageData
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .noImageData: "写真データの取得に失敗しました"
        case .saveFailed: "写真の保存に失敗しました"
        }
    }
}
