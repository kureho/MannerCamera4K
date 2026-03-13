import AVFoundation
import Photos
import SwiftUI

@Observable
final class CameraManager: NSObject {
    // MARK: - Public State
    var captureState: CaptureState = .idle
    var currentMode: CameraMode = .photo
    var currentLens: LensType = .wide
    var currentPosition: AVCaptureDevice.Position = .back
    var availableLenses: [LensType] = []
    var isNightModeEnabled: Bool = false
    var isFlashEnabled: Bool = false
    var isCameraPermissionGranted: Bool = false
    var zoomFactor: CGFloat = 1.0
    var recordingDuration: TimeInterval = 0
    var showStorageAlert: Bool = false

    // MARK: - Internal
    let session = AVCaptureSession()
    var currentDevice: AVCaptureDevice?
    private var deviceInput: AVCaptureDeviceInput?
    let photoOutput = AVCapturePhotoOutput()
    let movieOutput = AVCaptureMovieFileOutput()
    let videoDataOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let videoDataQueue = DispatchQueue(label: "camera.videodata.queue")

    private var recordingTimer: Timer?
    private let nightModeProcessor = NightModeProcessor()

    // 無音フレームキャプチャ用
    private var frameCaptureCompletion: ((CMSampleBuffer) -> Void)?

    // MARK: - Setup
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isCameraPermissionGranted = true
            sessionQueue.async { self.setupSession() }
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { _ in }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    self.isCameraPermissionGranted = granted
                    if granted {
                        self.sessionQueue.async { self.setupSession() }
                        PHPhotoLibrary.requestAuthorization(for: .addOnly) { _ in }
                    }
                }
            }
        default:
            isCameraPermissionGranted = false
        }
    }

    private func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
            deviceInput = input
            currentDevice = device
        }

        // PhotoOutput（48MP対応 — 有音撮影のフォールバック用に残す）
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .quality
            let supported = device.activeFormat.supportedMaxPhotoDimensions
            if let maxDim = supported.max(by: { Int($0.width) * Int($0.height) < Int($1.width) * Int($1.height) }) {
                photoOutput.maxPhotoDimensions = maxDim
            }
        }

        // VideoDataOutput（無音フレームキャプチャ用）
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataQueue)
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
        }

        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }

        session.commitConfiguration()
        session.startRunning()

        Task { @MainActor in
            self.availableLenses = DeviceCapability.availableLenses(for: self.currentPosition)
        }

        NotificationCenter.default.addObserver(
            forName: .AVCaptureSessionWasInterrupted,
            object: session,
            queue: .main
        ) { [weak self] _ in
            if self?.captureState == .recording {
                self?.stopRecording()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .AVCaptureSessionInterruptionEnded,
            object: session,
            queue: .main
        ) { [weak self] _ in
            self?.sessionQueue.async {
                self?.session.startRunning()
            }
        }
    }

    // MARK: - Lens Switching
    func switchLens(to lens: LensType) {
        guard lens != currentLens else { return }
        sessionQueue.async {
            guard let newDevice = DeviceCapability.device(for: lens, position: self.currentPosition),
                  let newInput = try? AVCaptureDeviceInput(device: newDevice) else { return }

            self.session.beginConfiguration()
            if let existing = self.deviceInput {
                self.session.removeInput(existing)
            }
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.deviceInput = newInput
                self.currentDevice = newDevice
                Task { @MainActor in
                    self.currentLens = lens
                    self.zoomFactor = 1.0
                }
            }
            self.session.commitConfiguration()
        }
    }

    // MARK: - Camera Position Toggle
    func toggleCameraPosition() {
        let newPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
        sessionQueue.async {
            guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
                  let newInput = try? AVCaptureDeviceInput(device: newDevice) else { return }

            self.session.beginConfiguration()
            if let existing = self.deviceInput {
                self.session.removeInput(existing)
            }
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.deviceInput = newInput
                self.currentDevice = newDevice
                Task { @MainActor in
                    self.currentPosition = newPosition
                    self.currentLens = .wide
                    self.availableLenses = DeviceCapability.availableLenses(for: newPosition)
                    self.zoomFactor = 1.0
                }
            }
            self.session.commitConfiguration()
        }
    }

    // MARK: - Focus
    func focus(at point: CGPoint, in viewSize: CGSize) {
        guard let device = currentDevice else { return }
        let focusPoint = CGPoint(
            x: point.y / viewSize.height,
            y: 1.0 - point.x / viewSize.width
        )
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = focusPoint
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = focusPoint
                    device.exposureMode = .autoExpose
                }
                device.unlockForConfiguration()
            } catch {}
        }
    }

    // MARK: - Zoom
    func setZoom(_ factor: CGFloat) {
        guard let device = currentDevice else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                let clamped = max(device.minAvailableVideoZoomFactor, min(factor, device.maxAvailableVideoZoomFactor))
                device.videoZoomFactor = clamped
                device.unlockForConfiguration()
                Task { @MainActor in
                    self.zoomFactor = clamped
                }
            } catch {}
        }
    }

    // MARK: - Silent Photo Capture (VideoDataOutput frame grab)
    func capturePhoto(settings: CameraSettings) {
        guard captureState == .idle else { return }

        guard StorageChecker.hasEnoughStorage() else {
            showStorageAlert = true
            return
        }

        captureState = .capturing

        // フラッシュ: トーチで代用
        if isFlashEnabled, let device = currentDevice, device.hasTorch {
            try? device.lockForConfiguration()
            device.torchMode = .on
            device.unlockForConfiguration()
        }

        // 次のビデオフレームをキャプチャ
        frameCaptureCompletion = { [weak self] sampleBuffer in
            guard let self else { return }
            self.frameCaptureCompletion = nil

            // トーチOFF
            if self.isFlashEnabled, let device = self.currentDevice, device.hasTorch {
                try? device.lockForConfiguration()
                device.torchMode = .off
                device.unlockForConfiguration()
            }

            // フレームを画像データに変換
            guard let imageData = self.imageDataFromSampleBuffer(sampleBuffer, settings: settings) else {
                Task { @MainActor in self.captureState = .idle }
                return
            }

            // ナイトモード処理
            let finalData: Data
            if self.isNightModeEnabled, let processed = self.nightModeProcessor.processImage(imageData) {
                finalData = processed
            } else {
                finalData = imageData
            }

            // 保存
            Task {
                do {
                    try await PhotoLibraryManager.savePhoto(finalData)
                } catch {
                    print("Photo save error: \(error)")
                }
                await MainActor.run { self.captureState = .idle }
            }
        }
    }

    private func imageDataFromSampleBuffer(_ sampleBuffer: CMSampleBuffer, settings: CameraSettings) -> Data? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        let uiImage = UIImage(cgImage: cgImage)

        if settings.photoFormat == .heif {
            return uiImage.heicData() ?? uiImage.jpegData(compressionQuality: 0.95)
        } else {
            return uiImage.jpegData(compressionQuality: 0.95)
        }
    }

    // MARK: - Video Recording
    private var _currentVideoCapturer: VideoCapturer?

    func startRecording(settings: CameraSettings) {
        guard captureState == .idle else { return }

        guard StorageChecker.hasEnoughStorage() else {
            showStorageAlert = true
            return
        }

        if settings.recordAudio && AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                Task { @MainActor in
                    self.beginRecording(settings: settings)
                }
            }
        } else {
            beginRecording(settings: settings)
        }
    }

    private func beginRecording(settings: CameraSettings) {
        // 録画中はビデオデータ出力を無効化（MovieFileOutputとの競合防止）
        videoDataOutput.setSampleBufferDelegate(nil, queue: nil)

        VideoCapturer.configureAudioSession()
        let capturer = VideoCapturer(movieOutput: movieOutput, session: session)
        _ = capturer.startRecording(resolution: settings.videoResolution, recordAudio: settings.recordAudio)
        captureState = .recording
        recordingDuration = 0
        _currentVideoCapturer = capturer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingDuration += 0.1
            }
        }
    }

    func stopRecording() {
        guard captureState == .recording, let capturer = _currentVideoCapturer else { return }

        recordingTimer?.invalidate()
        recordingTimer = nil

        Task {
            do {
                let url = try await capturer.stopRecording()
                try await PhotoLibraryManager.saveVideo(at: url)
                try? FileManager.default.removeItem(at: url)
            } catch {
                print("Video save error: \(error)")
            }
            await MainActor.run {
                self.captureState = .idle
                self.recordingDuration = 0
                self.sessionQueue.async {
                    self.session.beginConfiguration()
                    self.session.sessionPreset = .photo
                    self.session.commitConfiguration()
                    // 録画終了後にビデオデータ出力を再有効化
                    self.videoDataOutput.setSampleBufferDelegate(self, queue: self.videoDataQueue)
                }
            }
        }

        _currentVideoCapturer = nil
    }

    // MARK: - Flash
    func toggleFlash() {
        isFlashEnabled.toggle()
    }

    // MARK: - Night Mode
    func toggleNightMode() {
        isNightModeEnabled.toggle()
        guard let device = currentDevice else { return }

        sessionQueue.async {
            if self.isNightModeEnabled {
                self.nightModeProcessor.configureDevice(device)
            } else {
                self.nightModeProcessor.resetDevice(device)
            }
        }
    }

    // MARK: - Session Lifecycle
    func startSession() {
        sessionQueue.async {
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stopSession() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // フレームキャプチャ要求がある場合のみ処理
        if let completion = frameCaptureCompletion {
            completion(sampleBuffer)
        }
    }
}
