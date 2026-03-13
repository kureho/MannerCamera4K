import AVFoundation

final class VideoCapturer: NSObject {

    private let movieOutput: AVCaptureMovieFileOutput
    private let session: AVCaptureSession
    private var continuation: CheckedContinuation<URL, Error>?

    init(movieOutput: AVCaptureMovieFileOutput, session: AVCaptureSession) {
        self.movieOutput = movieOutput
        self.session = session
    }

    static func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("AudioSession configuration error: \(error)")
        }
    }

    func startRecording(resolution: VideoResolution, recordAudio: Bool) -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")

        // プリセット変更とオーディオ入力を1回のconfigurationにまとめ、黒画面を最小化
        session.beginConfiguration()

        switch resolution {
        case .fourK:
            if session.canSetSessionPreset(.hd4K3840x2160) {
                session.sessionPreset = .hd4K3840x2160
            }
        case .fullHD:
            if session.canSetSessionPreset(.hd1920x1080) {
                session.sessionPreset = .hd1920x1080
            }
        }

        // オーディオ入力も同じconfiguration内で追加
        configureAudioInput(enabled: recordAudio)

        session.commitConfiguration()

        movieOutput.startRecording(to: outputURL, recordingDelegate: self)
        return outputURL
    }

    func stopRecording() async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            movieOutput.stopRecording()
        }
    }

    private func configureAudioInput(enabled: Bool) {
        for input in session.inputs {
            if let deviceInput = input as? AVCaptureDeviceInput,
               deviceInput.device.hasMediaType(.audio) {
                session.removeInput(deviceInput)
            }
        }

        guard enabled else { return }

        // Critical 3: DispatchSemaphore を削除してデッドロック回避
        // 権限リクエストは CameraManager.startRecording で事前に行う
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else { return }
        addAudioInput()
    }

    private func addAudioInput() {
        guard let audioDevice = AVCaptureDevice.default(for: .audio),
              let audioInput = try? AVCaptureDeviceInput(device: audioDevice) else { return }
        if session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }
    }
}

extension VideoCapturer: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error {
            continuation?.resume(throwing: error)
            continuation = nil
            try? FileManager.default.removeItem(at: outputFileURL)
            return
        }
        continuation?.resume(returning: outputFileURL)
        continuation = nil
    }
}
