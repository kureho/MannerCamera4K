import SwiftUI
import AVFoundation

enum PhotoFormat: String, CaseIterable, Identifiable {
    case heif = "HEIF"
    case jpeg = "JPEG"
    var id: String { rawValue }
}

enum VideoResolution: String, CaseIterable, Identifiable {
    case fullHD = "1080p"
    case fourK = "4K"
    var id: String { rawValue }
    var displayName: String { rawValue }
}

enum PhotoResolution: String, CaseIterable, Identifiable {
    case standard = "standard"
    case high = "high"
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .standard: "12MP"
        case .high: "48MP"
        }
    }
}

final class CameraSettings: ObservableObject {
    private let defaults = UserDefaults.standard

    var photoFormat: PhotoFormat {
        get { PhotoFormat(rawValue: defaults.string(forKey: "photoFormat") ?? "HEIF") ?? .heif }
        set { defaults.set(newValue.rawValue, forKey: "photoFormat"); objectWillChange.send() }
    }

    var videoResolution: VideoResolution {
        get { VideoResolution(rawValue: defaults.string(forKey: "videoResolution") ?? "4K") ?? .fourK }
        set { defaults.set(newValue.rawValue, forKey: "videoResolution"); objectWillChange.send() }
    }

    var photoResolution: PhotoResolution {
        get { PhotoResolution(rawValue: defaults.string(forKey: "photoResolution") ?? "high") ?? .high }
        set { defaults.set(newValue.rawValue, forKey: "photoResolution"); objectWillChange.send() }
    }

    var recordAudio: Bool {
        get { defaults.object(forKey: "recordAudio") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "recordAudio"); objectWillChange.send() }
    }

    var hasShownMuteTip: Bool {
        get { defaults.bool(forKey: "hasShownMuteTip") }
        set { defaults.set(newValue, forKey: "hasShownMuteTip"); objectWillChange.send() }
    }
}
