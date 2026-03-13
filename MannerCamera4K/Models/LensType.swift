import AVFoundation

enum LensType: String, CaseIterable, Identifiable {
    case ultraWide
    case wide
    case telephoto

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ultraWide: "0.5x"
        case .wide: "1x"
        case .telephoto: "3x"
        }
    }

    var deviceType: AVCaptureDevice.DeviceType {
        switch self {
        case .ultraWide: .builtInUltraWideCamera
        case .wide: .builtInWideAngleCamera
        case .telephoto: .builtInTelephotoCamera
        }
    }
}
