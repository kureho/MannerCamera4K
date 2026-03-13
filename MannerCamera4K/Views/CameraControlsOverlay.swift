import SwiftUI

struct CameraControlsOverlay: View {
    @Bindable var camera: CameraManager
    let settings: CameraSettings
    let onCapture: () -> Void

    var body: some View {
        VStack {
            topControls
            Spacer()
            lensSelector
            bottomControls
        }
        .padding(.vertical, 16)
    }

    private var topControls: some View {
        HStack {
            Button {
                camera.toggleFlash()
            } label: {
                Image(systemName: camera.isFlashEnabled ? "bolt.fill" : "bolt.slash.fill")
                    .font(.title2)
                    .foregroundStyle(camera.isFlashEnabled ? .yellow : .white)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Button {
                camera.toggleNightMode()
            } label: {
                Image(systemName: camera.isNightModeEnabled ? "moon.fill" : "moon")
                    .font(.title2)
                    .foregroundStyle(camera.isNightModeEnabled ? .yellow : .white)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            NavigationLink {
                SettingsView(settings: settings)
            } label: {
                Image(systemName: "gearshape")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 24)
    }

    private var lensSelector: some View {
        HStack(spacing: 12) {
            if camera.currentPosition == .back {
                ForEach(camera.availableLenses) { lens in
                    Button {
                        camera.switchLens(to: lens)
                    } label: {
                        Text(lens.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(camera.currentLens == lens ? .yellow : .white)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(camera.currentLens == lens ? .white.opacity(0.2) : .clear)
                            )
                    }
                    // Important 13: 録画中はレンズ切替を無効化
                    .disabled(camera.captureState == .recording)
                }
            }
        }
        .padding(.bottom, 8)
    }

    private var bottomControls: some View {
        VStack(spacing: 16) {
            modeSelector

            HStack {
                if camera.currentMode == .video && camera.captureState == .recording {
                    recordingTimeLabel
                } else {
                    Color.clear.frame(width: 60, height: 44)
                }

                Spacer()

                ShutterButton(
                    mode: camera.currentMode,
                    captureState: camera.captureState,
                    onTap: onCapture
                )

                Spacer()

                Button {
                    camera.toggleCameraPosition()
                } label: {
                    Image(systemName: "camera.rotate")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 44)
                }
                // Important 13: 録画中はカメラ切替を無効化
                .disabled(camera.captureState == .recording)
            }
            .padding(.horizontal, 32)
        }
    }

    private var modeSelector: some View {
        HStack(spacing: 24) {
            ForEach(CameraMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        camera.currentMode = mode
                    }
                } label: {
                    Text(mode.displayName)
                        .font(.system(size: 15, weight: camera.currentMode == mode ? .bold : .regular))
                        .foregroundStyle(camera.currentMode == mode ? .yellow : .white.opacity(0.7))
                }
            }
        }
    }

    private var recordingTimeLabel: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
            Text(formatDuration(camera.recordingDuration))
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
        }
        .frame(width: 100, height: 44)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
