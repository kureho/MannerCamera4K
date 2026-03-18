# MannerCamera4K

## プロジェクト概要

iOS サイレントカメラアプリ。SwiftUI + AVFoundation で構築。

## 技術スタック

- **UI**: SwiftUI
- **カメラ制御**: AVFoundation (AVCaptureSession, AVCapturePhotoOutput, AVCaptureMovieFileOutput)
- **並行処理**: Swift Concurrency + sessionQueue (DispatchQueue)
- **対象**: iOS 17+, iPhone のみ, ポートレート固定

## 適用するスキル

| スキル | 用途 |
|--------|------|
| `superpowers:systematic-debugging` | バグ修正前に必ず使用 |
| `superpowers:test-driven-development` | 機能実装時 |
| `superpowers:verification-before-completion` | 完了宣言前 |
| `superpowers:brainstorming` | 設計・機能追加前 |
| `ui-ux-pro-max` | UI パターン探索（SwiftUI モード） |

## 適用しないスキル

以下は Web 専用のため、このプロジェクトでは invoke しないこと:
- `frontend-design`
- `web-design-guidelines`
- `vercel-react-best-practices`

## アーキテクチャ上の注意点

- `CameraManager` は `@Observable` だが `@MainActor` ではない — プロパティアクセスのスレッド安全性に注意
- カメラ操作は `sessionQueue` で実行し、UI 更新は `Task { @MainActor in }` で戻す
- `sessionQueue.async` に渡すクロージャでは、main thread のプロパティを事前キャプチャする
- `VideoCapturer` の continuation は `NSLock` で保護

## 教訓・参照

- 教訓: `tasks/lessons.md`
