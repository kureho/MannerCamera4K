import AVFoundation

// SilentPhotoCapturer は CameraManager のフレームキャプチャ方式に統合済み
// このファイルは共通エラー型の定義のみ残す

enum CaptureError: LocalizedError {
    case noImageData
    case saveFailed
    case timeout

    var errorDescription: String? {
        switch self {
        case .noImageData: "写真データの取得に失敗しました"
        case .saveFailed: "写真の保存に失敗しました"
        case .timeout: "撮影がタイムアウトしました"
        }
    }
}
