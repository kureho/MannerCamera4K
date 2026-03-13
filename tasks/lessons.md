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
