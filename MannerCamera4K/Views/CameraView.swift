import SwiftUI

struct CameraView: View {
    @State private var camera = CameraManager()
    @StateObject private var settings = CameraSettings()
    @State private var showMuteTip = false
    @State private var focusPoint: CGPoint?
    @State private var showFocusIndicator = false
    // Important 8: ズームの指数的増加バグ修正用ベースズーム
    @State private var baseZoom: CGFloat = 1.0
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if camera.isCameraPermissionGranted {
                    cameraContent
                } else {
                    PermissionDeniedView()
                }
            }
        }
        .onAppear {
            camera.checkPermission()
        }
        .onDisappear {
            camera.stopSession()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                camera.startSession()
            case .inactive, .background:
                if camera.captureState == .recording {
                    camera.stopRecording()
                }
                camera.stopSession()
            @unknown default:
                break
            }
        }
        .alert("ストレージ不足", isPresented: Bindable(camera).showStorageAlert) {
            Button("OK") {}
        } message: {
            Text("空き容量が不足しています。不要なファイルを削除してから再度お試しください。")
        }
    }

    private var cameraContent: some View {
        ZStack {
            GeometryReader { geo in
                CameraPreviewView(session: camera.session)
                    .ignoresSafeArea()
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                camera.focus(at: value.location, in: geo.size)
                                showFocusAt(value.location)
                            }
                    )
                    .gesture(
                        MagnifyGesture()
                            .onChanged { value in
                                // Important 8: baseZoom を基準にして指数的増加を防止
                                camera.setZoom(baseZoom * value.magnification)
                            }
                            .onEnded { _ in
                                baseZoom = camera.zoomFactor
                            }
                    )
            }

            if showFocusIndicator, let point = focusPoint {
                FocusIndicator()
                    .position(point)
            }

            if camera.captureState == .capturing && camera.isNightModeEnabled {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                        Text("撮影中...")
                            .foregroundStyle(.white)
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    Spacer()
                }
            }

            CameraControlsOverlay(
                camera: camera,
                settings: settings,
                onCapture: handleCapture
            )

            if showMuteTip {
                muteTipOverlay
            }
        }
    }

    private func handleCapture() {
        switch camera.currentMode {
        case .photo:
            camera.capturePhoto(settings: settings)

        case .video:
            if camera.captureState == .recording {
                camera.stopRecording()
            } else {
                if !settings.hasShownMuteTip {
                    showMuteTip = true
                    settings.hasShownMuteTip = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        showMuteTip = false
                    }
                }
                camera.startRecording(settings: settings)
            }
        }
    }

    private func showFocusAt(_ point: CGPoint) {
        focusPoint = point
        showFocusIndicator = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showFocusIndicator = false }
        }
    }

    private var muteTipOverlay: some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: "speaker.slash.fill")
                Text("サイレントモード（ミュートスイッチ）をONにすると録画音も消えます")
                    .font(.caption)
            }
            .foregroundStyle(.white)
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 24)
            .padding(.top, 80)

            Spacer()
        }
        .transition(.opacity)
    }
}

struct FocusIndicator: View {
    @State private var scale: CGFloat = 1.5
    @State private var opacity: Double = 1.0

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .stroke(.yellow, lineWidth: 1.5)
            .frame(width: 70, height: 70)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.3)) {
                    scale = 1.0
                }
                withAnimation(.easeOut(duration: 1.0).delay(0.8)) {
                    opacity = 0
                }
            }
    }
}
