# 教訓

## iOS カメラアプリ開発

### 無音撮影（日本リージョン・iOS 18+）
- `isShutterSoundSuppressionEnabled` (iOS 18 公式API): 日本では動作しない
- Live Photos 方式: iOS 18+ では音が消えない
- `AudioServicesDisposeSystemSoundID(1108)`: iOS 18+ では無効化されている
- **唯一の確実な方法: `AVCaptureVideoDataOutput` のフレームキャプチャ**
  - ビデオストリームからフレームを取得するため、シャッター音の仕組みを通らない
  - 解像度は12MP（48MPは不可）だが実用上十分
  - フラッシュはトーチで代用

### AVCapturePhotoOutput の maxPhotoDimensions
- `photoSettings.maxPhotoDimensions` を設定する前に、`photoOutput.maxPhotoDimensions` をセッション構成時に設定する必要がある
- 設定しないとクラッシュする（エラーメッセージなし）
- `device.formats` 全体ではなく `device.activeFormat.supportedMaxPhotoDimensions` から取得すること

### AVCaptureVideoDataOutput と AVCaptureMovieFileOutput の共存
- 同一セッションで両方使用可能だが、動画録画中は VideoDataOutput の delegate を nil にする
- 録画終了後に delegate を再設定する
- 競合すると録画停止が効かなくなる

### 写真ライブラリ権限
- カメラ権限取得直後に `PHPhotoLibrary.requestAuthorization(for: .addOnly)` を呼ぶ
- 初回撮影時にダイアログが重なるとフリーズの原因になる

### UI レイアウト
- HStack で中央のボタンを固定位置にする場合、左右の要素の幅を揃える
- 状態によって表示が切り替わる要素は、非表示時も同じ frame サイズの placeholder を置く

### SwiftUI ジェスチャーとボタンの競合
- `DragGesture(minimumDistance: 0)` は全タッチイベントを消費し、ZStack 上位のボタンのタップを奪う
- タップ位置が必要な場合は `SpatialTapGesture` を使う（ボタンと共存可能）
- この問題は特定の状態（録画中など）でのみ再現するため見落としやすい

### CIContext の再利用
- `CIContext()` は重いオブジェクトなので毎回生成しない
- インスタンス変数として保持して再利用する

## App Store 審査

### Guideline 2.5.14 — 撮影インジケーター
- 無音カメラアプリでは、撮影時に**被写体にも見える視覚的インジケーター**が必須
- `Color.black` のフラッシュはNG（「go blank during recording」と判定される）
- `Color.white` の白フラッシュが適切（Microsoft Pix等と同様の方式）
- インジケーターは無効化できてはいけない

### Guideline 2.3.7 — スクリーンショットに価格を入れない
- App Store のスクリーンショットに具体的な価格（¥400等）を含めるとリジェクト
- 「買い切り」「広告なし」等の表現はOK、金額はNG
- 価格は説明文（Description）に記載する

### Guideline 1.5 — サポートURL
- FAQ だけでは不十分。ユーザーが**質問を送信できる手段**が必要
- お問い合わせフォーム or メールアドレスを必ず含める
- GitHub Issues だけだと不十分な場合がある

### 共有サポートサイト
- `support-desk.vercel.app` で複数アプリ共通のお問い合わせフォームを運用
- DB は stream-schedule と同じ Supabase を共用（テーブル名 `support_submissions` で分離）
- 新アプリ追加時は `src/lib/products.ts` にエントリを追加するだけ

## プロセス・スキル運用

### スキルの誤適用に注意
- Web 専用スキル（`frontend-design`, `web-design-guidelines`, `vercel-react-best-practices`）を iOS プロジェクトに適用しない
- → `design-skills.md` にプラットフォーム適用テーブルを追加、プロジェクト CLAUDE.md で明示除外で対策済み

### バグ修正は systematic-debugging → TDD の順で行う
- 場当たり的に修正すると「修正 → 新バグ発生 → 修正 → 新バグ」のサイクルに陥る
- 根本原因: CameraManager のスレッド安全性が構造的に保証されていない（`@Observable` だが `@MainActor` なし）
- **修正前に必ず `systematic-debugging` で根本原因を特定し、`TDD` でテストを書いてから修正する**

### sessionQueue.async クロージャでの値キャプチャ
- main thread のプロパティを `sessionQueue.async { }` 内で直接参照すると、実行時に値が変わっている可能性がある
- dispatch 前にローカル変数にキャプチャしてからクロージャに渡す
- 例: `let nightModeOn = isNightModeEnabled` → `sessionQueue.async { ... nightModeOn ... }`
