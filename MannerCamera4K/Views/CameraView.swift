import SwiftUI

struct CameraView: View {
    @State private var camera = CameraManager()
    @StateObject private var settings = CameraSettings()
    @State private var showMuteTip = false
    @State private var focusPoint: CGPoint?
    @State private var showFocusIndicator = false
    @State private var focusID = UUID()
    // Important 8: ズームの指数的増加バグ修正用ベースズーム
    @State private var baseZoom: CGFloat = 1.0
    @State private var showShutterFlash = false
    @State private var showCaptureConfirm = false
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
                // 権限の付与・取消の両方に対応（内部で startSession も行う）
                camera.checkPermission()
            case .background:
                // バックグラウンド移行時のみ録画停止（.inactiveではコントロールセンター等で発火するため停止しない）
                // stopRecording は内部で非同期に保存処理を行うため、stopSession は captureState が idle に戻ってから実行
                if camera.captureState == .recording {
                    camera.stopRecording()
                }
                // 録画停止の非同期処理と競合しないよう sessionQueue 経由で順序を保証
                camera.stopSession()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
        .onChange(of: camera.currentLens) {
            baseZoom = 1.0
        }
        .onChange(of: camera.currentPosition) {
            baseZoom = 1.0
        }
        .alert("ストレージ不足", isPresented: Bindable(camera).showStorageAlert) {
            Button("OK") {}
        } message: {
            Text("空き容量が不足しています。不要なファイルを削除してから再度お試しください。")
        }
        .alert("保存に失敗しました", isPresented: Bindable(camera).showSaveErrorAlert) {
            Button("OK") {}
        } message: {
            Text("写真ライブラリへの保存に失敗しました。設定アプリから写真へのアクセスを許可してください。")
        }
    }

    private var cameraContent: some View {
        ZStack {
            GeometryReader { geo in
                CameraPreviewView(session: camera.session)
                    .ignoresSafeArea()
                    // 録画中・キャプチャ中はプレビューのタッチを完全に無効化
                    // これにより録画停止ボタンへのタッチが確実に到達する
                    .allowsHitTesting(camera.captureState == .idle)
                    .gesture(
                        SpatialTapGesture()
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
                    .id(focusID)
                    .position(point)
                    .allowsHitTesting(false)
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
                .allowsHitTesting(false)
            }

            if showShutterFlash {
                Color.white
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .zIndex(10)
            }

            if showCaptureConfirm {
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                            Text("撮影しました")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.7), in: Capsule())
                        .padding(.trailing, 16)
                        .padding(.top, 56)
                    }
                    Spacer()
                }
                .allowsHitTesting(false)
                .transition(.opacity)
                .zIndex(11)
            }

            CameraControlsOverlay(
                camera: camera,
                settings: settings,
                onCapture: handleCapture
            )

            if showMuteTip {
                muteTipOverlay
                    .allowsHitTesting(false)
            }
        }
    }

    private func handleCapture() {
        switch camera.currentMode {
        case .photo:
            // 2.5.14: 白フラッシュ（全関係者に撮影を通知するインジケーター）
            withAnimation(.easeOut(duration: 0.05)) {
                showShutterFlash = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeIn(duration: 0.2)) {
                    showShutterFlash = false
                }
            }
            // 2.5.14: 撮影完了確認バッジ（フラッシュ後に1.5秒表示）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeOut(duration: 0.15)) {
                    showCaptureConfirm = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.85) {
                withAnimation(.easeIn(duration: 0.3)) {
                    showCaptureConfirm = false
                }
            }
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
        focusID = UUID()
        showFocusIndicator = true
        let currentID = focusID
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // 新しいタップが発生していない場合のみ非表示にする
            if focusID == currentID {
                withAnimation { showFocusIndicator = false }
            }
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
