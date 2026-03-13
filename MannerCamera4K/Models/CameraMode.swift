import Foundation

enum CameraMode: String, CaseIterable {
    case photo
    case video

    var displayName: String {
        switch self {
        case .photo: "写真"
        case .video: "ビデオ"
        }
    }
}
