import AVFoundation

final class VideoCapturer: NSObject {

    private let movieOutput: AVCaptureMovieFileOutput
    private let session: AVCaptureSession
    private var continuation: CheckedContinuation<URL, Error>?
    private let continuationLock = NSLock()

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
            continuationLock.lock()
            if self.continuation != nil {
                continuationLock.unlock()
                continuation.resume(throwing: CancellationError())
                return
            }
            self.continuation = continuation
            continuationLock.unlock()
            if movieOutput.isRecording {
                movieOutput.stopRecording()
            } else {
                // 録画が実際に行われていない場合は即座にエラーで resume
                continuationLock.lock()
                let cont = self.continuation
                self.continuation = nil
                continuationLock.unlock()
                cont?.resume(throwing: CancellationError())
            }
        }
    }

    /// セッション中断時など、外部から continuation を強制的にキャンセルする
    func cancelIfNeeded() {
        continuationLock.lock()
        let cont = continuation
        continuation = nil
        continuationLock.unlock()
        cont?.resume(throwing: CancellationError())
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
        continuationLock.lock()
        let cont = continuation
        continuation = nil
        continuationLock.unlock()

        guard let cont else {
            // continuation が既に消費済み（cancelIfNeeded 等）→ 一時ファイルを削除
            try? FileManager.default.removeItem(at: outputFileURL)
            return
        }

        if let error {
            cont.resume(throwing: error)
            try? FileManager.default.removeItem(at: outputFileURL)
        } else {
            cont.resume(returning: outputFileURL)
        }
    }
}
