import AVFoundation
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
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")

    private var recordingTimer: Timer?

    // MARK: - Setup
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isCameraPermissionGranted = true
            sessionQueue.async { self.setupSession() }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    self.isCameraPermissionGranted = granted
                    if granted {
                        self.sessionQueue.async { self.setupSession() }
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

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .quality
        }

        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }

        session.commitConfiguration()
        session.startRunning()

        Task { @MainActor in
            self.availableLenses = DeviceCapability.availableLenses(for: self.currentPosition)
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

    // MARK: - Photo Capture
    func capturePhoto(settings: CameraSettings) {
        guard captureState == .idle else { return }

        guard StorageChecker.hasEnoughStorage() else {
            showStorageAlert = true
            return
        }

        captureState = .capturing

        let capturer = SilentPhotoCapturer(
            photoOutput: photoOutput,
            settings: settings,
            currentDevice: currentDevice,
            currentLens: currentLens,
            cameraPosition: currentPosition
        )

        Task {
            do {
                try await capturer.capturePhoto(
                    flashEnabled: isFlashEnabled,
                    nightMode: isNightModeEnabled
                )
                await MainActor.run { self.captureState = .idle }
            } catch {
                print("Photo capture error: \(error)")
                await MainActor.run { self.captureState = .idle }
            }
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

        VideoCapturer.configureAudioSession()

        let capturer = VideoCapturer(movieOutput: movieOutput, session: session)
        _ = capturer.startRecording(
            resolution: settings.videoResolution,
            recordAudio: settings.recordAudio
        )

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
                }
            }
        }

        _currentVideoCapturer = nil
    }

    // MARK: - Flash
    func toggleFlash() {
        isFlashEnabled.toggle()
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
