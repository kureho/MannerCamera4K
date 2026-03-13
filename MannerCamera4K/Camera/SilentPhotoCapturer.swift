import AVFoundation
import Photos

final class SilentPhotoCapturer: NSObject {

    private let photoOutput: AVCapturePhotoOutput
    private let settings: CameraSettings
    private let currentDevice: AVCaptureDevice?
    private let currentLens: LensType
    private let cameraPosition: AVCaptureDevice.Position
    private var continuation: CheckedContinuation<Void, Error>?

    // Critical 1: ナイトモード処理用プロパティ
    private let nightModeEnabled: Bool
    private let nightModeProcessor: NightModeProcessor?

    init(
        photoOutput: AVCapturePhotoOutput,
        settings: CameraSettings,
        currentDevice: AVCaptureDevice?,
        currentLens: LensType,
        cameraPosition: AVCaptureDevice.Position,
        nightModeEnabled: Bool = false,
        nightModeProcessor: NightModeProcessor? = nil
    ) {
        self.photoOutput = photoOutput
        self.settings = settings
        self.currentDevice = currentDevice
        self.currentLens = currentLens
        self.cameraPosition = cameraPosition
        self.nightModeEnabled = nightModeEnabled
        self.nightModeProcessor = nightModeProcessor
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
        // Critical 2: continuation を先に nil にして二重呼び出しを防止
        guard let cont = continuation else { return }
        continuation = nil

        if let error {
            cont.resume(throwing: error)
            return
        }

        guard let imageData = photo.fileDataRepresentation() else {
            cont.resume(throwing: CaptureError.noImageData)
            return
        }

        // Critical 1: ナイトモードのポスト処理を写真撮影パスで適用
        let finalData: Data
        if nightModeEnabled, let processor = nightModeProcessor, let processed = processor.processImage(imageData) {
            finalData = processed
        } else {
            finalData = imageData
        }

        Task {
            do {
                try await PhotoLibraryManager.savePhoto(finalData)
                cont.resume()
            } catch {
                cont.resume(throwing: error)
            }
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
