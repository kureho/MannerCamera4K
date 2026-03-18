import AVFoundation
import Photos
import SwiftUI

@Observable
@MainActor
final class CameraManager: NSObject {
    // MARK: - Public State (main-actor-isolated — SwiftUI から安全にアクセス可能)
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
    var showSaveErrorAlert: Bool = false

    // MARK: - Camera Hardware (nonisolated — sessionQueue/videoDataQueue からアクセス)
    nonisolated(unsafe) let session = AVCaptureSession()
    nonisolated(unsafe) var currentDevice: AVCaptureDevice?
    nonisolated(unsafe) private var deviceInput: AVCaptureDeviceInput?
    nonisolated(unsafe) let photoOutput = AVCapturePhotoOutput()
    nonisolated(unsafe) let movieOutput = AVCaptureMovieFileOutput()
    nonisolated(unsafe) let videoDataOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let videoDataQueue = DispatchQueue(label: "camera.videodata.queue")
    nonisolated(unsafe) private let nightModeProcessor = NightModeProcessor()
    nonisolated(unsafe) private let ciContext = CIContext()
    nonisolated(unsafe) private var isSessionConfigured = false

    // 無音フレームキャプチャ用（videoDataQueue からのみアクセスすること）
    nonisolated(unsafe) private var _frameCaptureCompletion: ((CMSampleBuffer) -> Void)?

    // MARK: - Recording State (nonisolated(unsafe) — deinit からのアクセスに必要)
    nonisolated(unsafe) private var recordingTimer: Timer?
    nonisolated(unsafe) private var recordingStartDate: Date?
    nonisolated(unsafe) private var notificationObservers: [Any] = []

    private var _currentVideoCapturer: VideoCapturer?
    private var isRecordingStarted = false

    deinit {
        recordingTimer?.invalidate()
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Setup
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            if !isCameraPermissionGranted {
                isCameraPermissionGranted = true
                sessionQueue.async { self.setupSession() }
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { _ in }
            } else {
                startSession()
            }
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

    nonisolated private func setupSession() {
        guard !isSessionConfigured else { return }
        isSessionConfigured = true

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

        let position: AVCaptureDevice.Position = .back
        Task { @MainActor in
            self.availableLenses = DeviceCapability.availableLenses(for: position)
        }

        let interruptionObserver = NotificationCenter.default.addObserver(
            forName: .AVCaptureSessionWasInterrupted,
            object: session,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.handleSessionInterruption()
            }
        }

        let resumeObserver = NotificationCenter.default.addObserver(
            forName: .AVCaptureSessionInterruptionEnded,
            object: session,
            queue: .main
        ) { [weak self] _ in
            self?.sessionQueue.async {
                self?.session.startRunning()
            }
        }

        notificationObservers = [interruptionObserver, resumeObserver]
    }

    private func handleSessionInterruption() {
        if captureState == .recording {
            recordingTimer?.invalidate()
            recordingTimer = nil
            recordingStartDate = nil
            _currentVideoCapturer?.cancelIfNeeded()
            _currentVideoCapturer = nil
            isRecordingStarted = false
            captureState = .idle
            recordingDuration = 0
            sessionQueue.async {
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo
                self.session.commitConfiguration()
                self.videoDataOutput.setSampleBufferDelegate(self, queue: self.videoDataQueue)
            }
        } else if captureState == .capturing {
            videoDataQueue.async {
                self._frameCaptureCompletion = nil
            }
            captureState = .idle
            // トーチが点灯中ならOFF
            if isFlashEnabled, let device = currentDevice, device.hasTorch {
                sessionQueue.async {
                    try? device.lockForConfiguration()
                    device.torchMode = .off
                    device.unlockForConfiguration()
                }
            }
        }
    }

    // MARK: - Lens Switching
    func switchLens(to lens: LensType) {
        guard lens != currentLens else { return }
        let position = currentPosition
        let nightModeOn = isNightModeEnabled
        sessionQueue.async {
            guard let newDevice = DeviceCapability.device(for: lens, position: position),
                  let newInput = try? AVCaptureDeviceInput(device: newDevice) else { return }

            self.session.beginConfiguration()
            if let existing = self.deviceInput {
                self.session.removeInput(existing)
            }
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.deviceInput = newInput
                self.currentDevice = newDevice
                if nightModeOn {
                    self.nightModeProcessor.configureDevice(newDevice)
                }
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
        let nightModeOn = isNightModeEnabled
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
                if nightModeOn {
                    self.nightModeProcessor.configureDevice(newDevice)
                }
                Task { @MainActor in
                    self.currentPosition = newPosition
                    self.currentLens = .wide
                    self.availableLenses = DeviceCapability.availableLenses(for: newPosition)
                    self.zoomFactor = 1.0
                    if newPosition == .front {
                        self.isFlashEnabled = false
                    }
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

        let flashEnabled = isFlashEnabled
        let device = currentDevice
        let nightModeOn = isNightModeEnabled
        let photoFormat = settings.photoFormat

        // フラッシュ: トーチで代用（デバイス操作は sessionQueue で実行）
        if flashEnabled, let device, device.hasTorch {
            sessionQueue.async {
                try? device.lockForConfiguration()
                device.torchMode = .on
                device.unlockForConfiguration()
            }
        }

        // タイムアウト: 3秒以内にフレームが取得できなければ .idle に戻す
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self, self.captureState == .capturing else { return }
            self.captureState = .idle
            self.videoDataQueue.async {
                self._frameCaptureCompletion = nil
            }
            if flashEnabled, let device, device.hasTorch {
                self.sessionQueue.async {
                    try? device.lockForConfiguration()
                    device.torchMode = .off
                    device.unlockForConfiguration()
                }
            }
        }

        // 次のビデオフレームをキャプチャ（videoDataQueue で設定してデータ競合を防止）
        videoDataQueue.async {
            self._frameCaptureCompletion = { [weak self] sampleBuffer in
                guard let self else { return }
                self._frameCaptureCompletion = nil

                // トーチOFF（デバイス操作は sessionQueue で実行）
                if flashEnabled, let device, device.hasTorch {
                    self.sessionQueue.async {
                        try? device.lockForConfiguration()
                        device.torchMode = .off
                        device.unlockForConfiguration()
                    }
                }

                // フレームからCIImageを取得
                guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                    Task { @MainActor in self.captureState = .idle }
                    return
                }
                var ciImage = CIImage(cvPixelBuffer: pixelBuffer)

                // ナイトモード処理
                if nightModeOn {
                    ciImage = self.nightModeProcessor.processCIImage(ciImage)
                }

                // CIImage → Data に変換
                guard let cgImage = self.ciContext.createCGImage(ciImage, from: ciImage.extent) else {
                    Task { @MainActor in self.captureState = .idle }
                    return
                }
                let uiImage = UIImage(cgImage: cgImage)
                let finalData: Data?
                if photoFormat == .heif {
                    finalData = uiImage.heicData() ?? uiImage.jpegData(compressionQuality: 0.95)
                } else {
                    finalData = uiImage.jpegData(compressionQuality: 0.95)
                }

                guard let imageData = finalData else {
                    Task { @MainActor in self.captureState = .idle }
                    return
                }

                // 保存
                Task {
                    do {
                        try await PhotoLibraryManager.savePhoto(imageData)
                    } catch {
                        print("Photo save error: \(error)")
                        await MainActor.run { self.showSaveErrorAlert = true }
                    }
                    await MainActor.run { self.captureState = .idle }
                }
            }
        }
    }

    // MARK: - Video Recording
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

        captureState = .recording
        recordingDuration = 0

        let capturer = VideoCapturer(movieOutput: movieOutput, session: session)
        _currentVideoCapturer = capturer

        let nightModeOn = isNightModeEnabled
        let device = currentDevice
        isRecordingStarted = false
        sessionQueue.async {
            if nightModeOn, let device {
                self.nightModeProcessor.resetDevice(device)
            }
            VideoCapturer.configureAudioSession()
            _ = capturer.startRecording(resolution: settings.videoResolution, recordAudio: settings.recordAudio)
            Task { @MainActor in
                self.isRecordingStarted = true
            }
        }

        recordingStartDate = Date()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let start = self.recordingStartDate else { return }
                self.recordingDuration = Date().timeIntervalSince(start)
            }
        }
    }

    func stopRecording() {
        guard captureState == .recording, let capturer = _currentVideoCapturer else { return }

        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartDate = nil
        _currentVideoCapturer = nil

        let nightModeOn = isNightModeEnabled
        let device = currentDevice

        // 録画が実際に開始されていない場合はキャプチャラーをキャンセルしてセッション復元
        guard isRecordingStarted else {
            capturer.cancelIfNeeded()
            captureState = .idle
            recordingDuration = 0
            sessionQueue.async {
                // sessionQueue 上で録画開始がディスパッチ済みの場合に備え、録画中なら停止
                if self.movieOutput.isRecording {
                    self.movieOutput.stopRecording()
                }
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo
                self.session.commitConfiguration()
                self.videoDataOutput.setSampleBufferDelegate(self, queue: self.videoDataQueue)
                if nightModeOn, let device {
                    self.nightModeProcessor.configureDevice(device)
                }
            }
            return
        }
        isRecordingStarted = false

        Task {
            do {
                let url = try await capturer.stopRecording()
                do {
                    try await PhotoLibraryManager.saveVideo(at: url)
                } catch {
                    print("Video save error: \(error)")
                    await MainActor.run { self.showSaveErrorAlert = true }
                }
                try? FileManager.default.removeItem(at: url)
            } catch {
                print("Recording stop error: \(error)")
            }
            await MainActor.run {
                self.captureState = .idle
                self.recordingDuration = 0
                self.sessionQueue.async {
                    self.session.beginConfiguration()
                    self.session.sessionPreset = .photo
                    self.session.commitConfiguration()
                    self.videoDataOutput.setSampleBufferDelegate(self, queue: self.videoDataQueue)
                    if nightModeOn, let device {
                        self.nightModeProcessor.configureDevice(device)
                    }
                }
            }
        }
    }

    // MARK: - Flash
    func toggleFlash() {
        isFlashEnabled.toggle()
    }

    // MARK: - Night Mode
    func toggleNightMode() {
        isNightModeEnabled.toggle()
        let enabled = isNightModeEnabled
        guard let device = currentDevice else { return }

        sessionQueue.async {
            if enabled {
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
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // フレームキャプチャ要求がある場合のみ処理（videoDataQueue 上で実行される）
        if let completion = _frameCaptureCompletion {
            completion(sampleBuffer)
        }
    }
}
