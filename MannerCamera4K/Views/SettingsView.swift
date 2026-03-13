import SwiftUI
import AVFoundation

struct SettingsView: View {
    @ObservedObject var settings: CameraSettings
    @State private var micPermission: AVAuthorizationStatus = .notDetermined

    var body: some View {
        List {
            Section("写真") {
                Picker("保存形式", selection: Binding(
                    get: { settings.photoFormat },
                    set: { settings.photoFormat = $0 }
                )) {
                    ForEach(PhotoFormat.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }

                if DeviceCapability.supports48MP() {
                    Picker("解像度", selection: Binding(
                        get: { settings.photoResolution },
                        set: { settings.photoResolution = $0 }
                    )) {
                        ForEach(PhotoResolution.allCases) { res in
                            Text(res.displayName).tag(res)
                        }
                    }
                }
            }

            Section("動画") {
                Picker("解像度", selection: Binding(
                    get: { settings.videoResolution },
                    set: { settings.videoResolution = $0 }
                )) {
                    ForEach(VideoResolution.allCases) { res in
                        Text(res.displayName).tag(res)
                    }
                }

                Toggle("音声を録音", isOn: Binding(
                    get: { settings.recordAudio },
                    set: { settings.recordAudio = $0 }
                ))

                if micPermission == .denied || micPermission == .restricted {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "mic.slash")
                                .foregroundStyle(.red)
                            Text("マイクの権限が無効です。設定から有効にしてください")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                HStack {
                    Text("バージョン")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            micPermission = AVCaptureDevice.authorizationStatus(for: .audio)
        }
    }
}
