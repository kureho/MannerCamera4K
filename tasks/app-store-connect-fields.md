# App Store Connect 全入力項目ガイド — マナーカメラ 4K

対象: com.Kureho.MannerCamera4K
最終更新: 2026-03-14
参照時点: 2025-2026年のApp Store Connect

---

## 1. 新規アプリレコード作成時（初回のみ）

| フィールド名 | 入力タイプ | 推奨入力値 |
|---|---|---|
| プラットフォーム | 選択 | iOS |
| アプリ名 | テキスト（30文字以内） | マナーカメラ 4K |
| プライマリ言語 | 選択 | 日本語 |
| Bundle ID | 選択 | com.Kureho.MannerCamera4K |
| SKU | テキスト | MannerCamera4K（任意の一意識別子、非公開） |

---

## 2. App情報（App Information）セクション

### 2-1. 一般情報

| フィールド名 | 入力タイプ | 必須 | 推奨入力値 |
|---|---|---|---|
| アプリ名 | テキスト（30文字以内） | 必須 | マナーカメラ 4K |
| サブタイトル | テキスト（30文字以内） | 任意（強く推奨） | 無音シャッターの高画質カメラ |
| プライマリカテゴリ | 選択 | 必須 | 写真/ビデオ |
| セカンダリカテゴリ | 選択 | 任意 | ユーティリティ |
| コンテンツ配信権 | 選択 | 必須 | 「サードパーティコンテンツを使用していない」を選択 |
| 年齢制限指定 | アンケート形式 | 必須 | 下記セクション3参照 |
| プライバシーポリシーURL | URL | 必須 | https://[あなたのドメイン]/privacy-policy |
| ユーザープライバシー選択URL | URL | 任意 | （設定不要） |

### 2-2. ローカライゼーション

各言語ごとにアプリ名・サブタイトルを設定可能。日本語のみで開始する場合は1言語分のみ。

---

## 3. 年齢制限指定（Age Rating）— 2025年7月更新版

### 3-1. 新しい年齢区分（2025年7月〜）

| 区分 | 説明 |
|---|---|
| 4+ | 全年齢向け |
| 9+ | 軽微な暴力・恐怖表現 |
| 13+ | 新設（旧12+を置き換え）- 中程度のコンテンツ |
| 16+ | 新設 - 成熟したコンテンツ |
| 18+ | 旧17+を置き換え - 成人向け |

### 3-2. コンテンツ記述子（Content Descriptors）

各項目に対して頻度を選択: **「なし」/「まれ/軽度」/「頻繁/激しい」**

| コンテンツ記述子 | 推奨回答 | 理由 |
|---|---|---|
| マンガ的またはファンタジーの暴力 (Cartoon or Fantasy Violence) | なし | カメラアプリに暴力コンテンツなし |
| リアルな暴力 (Realistic Violence) | なし | 同上 |
| 性的コンテンツまたはヌード (Sexual Content or Nudity) | なし | なし |
| 不敬またはユーモア (Profanity or Crude Humor) | なし | なし |
| アルコール・タバコ・薬物の使用 (Alcohol, Tobacco, or Drug Use or References) | なし | なし |
| 成熟した内容/性的な示唆 (Mature/Suggestive Themes) | なし | なし |
| ホラー/恐怖表現 (Horror/Fear Themes) | なし | なし |
| 医学的/治療的情報 (Medical/Treatment Information) | なし | なし |
| 模擬ギャンブル (Simulated Gambling) | なし | なし |
| コンテスト (Contests) | なし | なし |

### 3-3. 新設質問: アプリ内コントロール（In-App Controls）

| 質問 | 推奨回答 | 理由 |
|---|---|---|
| ペアレンタルコントロール/保護者向けツールを提供するか | いいえ | カメラアプリには不要 |
| コンテンツフィルタリング機能があるか | いいえ | ユーザーコンテンツを扱わない |

### 3-4. 新設質問: 機能・能力（Capabilities）

| 質問 | 推奨回答 | 理由 |
|---|---|---|
| 制限なしのウェブアクセスを提供するか (Unrestricted Web Access) | いいえ | ブラウザ機能なし |
| ユーザー生成コンテンツを許可するか (User-Generated Content) | いいえ | 写真は端末内保存のみ、共有/投稿機能なし |
| アプリ内メッセージ/チャット機能があるか (In-App Messaging) | いいえ | なし |
| 位置情報を使用するか (Location Services) | 写真のExifに含まれる場合「はい」 | 写真メタデータ用 |

### 3-5. 新設質問: 医療・ウェルネス（Medical or Wellness Topics）

| 質問 | 推奨回答 | 理由 |
|---|---|---|
| 医療・健康関連のアドバイスや情報を提供するか | いいえ | カメラアプリに該当なし |

### 3-6. 新設質問: 暴力的テーマ（Violent Themes）

| 質問 | 推奨回答 | 理由 |
|---|---|---|
| 暴力的テーマを含むか | いいえ | カメラアプリに該当なし |

### 3-7. 想定される年齢制限結果

上記の回答で **4+**（全年齢向け）が付与される見込み。

---

## 4. 価格および配信状況（Pricing and Availability）セクション

| フィールド名 | 入力タイプ | 推奨入力値 |
|---|---|---|
| 価格 | 価格ポイント選択 | ¥400（価格ポイント選択で400円に相当するものを選択。Appleの価格体系に基づき自動計算） |
| 基準通貨/テリトリー | 選択 | 日本（JPY） |
| 配信地域 | チェックボックス（国・地域） | 日本のみ（または全世界） |
| 価格スケジュール | 日付+価格 | 即時公開で¥400 |
| プレオーダー | 選択 | いいえ（通常公開） |
| 教育機関向けディスカウント | チェックボックス | いいえ |
| ビジネス向け配信（Apple Business Manager） | チェックボックス | 任意（デフォルトで可） |

---

## 5. バージョン情報（Version Information）セクション

### 5-1. スクリーンショットとプレビュー

| フィールド名 | 入力タイプ | 推奨入力値 |
|---|---|---|
| iPhone 6.9インチスクリーンショット | 画像アップロード（1〜10枚） | iPhone 16 Pro Max サイズ（1320 x 2868 px）のスクリーンショット |
| iPhone 6.7インチスクリーンショット | 画像アップロード（1〜10枚） | iPhone 15 Pro Max サイズ（1290 x 2796 px）※6.9で代用可 |
| iPhone 6.5インチスクリーンショット | 画像アップロード（1〜10枚） | 省略可（6.7/6.9で代用可能な場合） |
| iPhone 5.5インチスクリーンショット | 画像アップロード（1〜10枚） | iPhone 8 Plus サイズ（1242 x 2208 px）※旧端末用 |
| アプリプレビュー動画 | 動画アップロード（0〜3本/サイズ） | 任意（30秒以内の操作デモ推奨） |

※ iPad非対応のためiPadスクリーンショットは不要

### 5-2. テキスト情報

| フィールド名 | 入力タイプ | 文字制限 | 推奨入力値 |
|---|---|---|---|
| プロモーションテキスト | テキスト | 170文字 | セール情報やアップデート告知に使用（検索には影響しない。初回は空でも可） |
| 説明 | テキスト | 4,000文字 | シャッター音を一切鳴らさずに写真・動画を撮影できるカメラアプリ。4K動画撮影、ナイトモード対応、高画質な写真撮影をマナーモードで。（詳細な説明文を作成） |
| キーワード | テキスト | 100文字 | 無音カメラ,マナーカメラ,シャッター音なし,4K動画,ナイトモード,高画質,消音カメラ,サイレントカメラ |
| 新機能（What's New） | テキスト | 4,000文字 | 初回リリースなので「初回リリース」または機能一覧 |

### 5-3. 一般的なApp情報

| フィールド名 | 入力タイプ | 推奨入力値 |
|---|---|---|
| サポートURL | URL（必須） | https://[あなたのドメイン]/support |
| マーケティングURL | URL（任意） | https://[あなたのドメイン]/ |
| バージョン番号 | テキスト | 1.0（Xcodeのビルドと一致させる） |
| 著作権 | テキスト | © 2026 [開発者名/会社名] |

### 5-4. ビルド

| フィールド名 | 入力タイプ | 推奨入力値 |
|---|---|---|
| ビルド | 選択（アップロード済みビルドから） | Xcode/Transporter経由でアップロードしたビルドを選択 |

---

## 6. Appレビュー情報（App Review Information）セクション

| フィールド名 | 入力タイプ | 必須 | 推奨入力値 |
|---|---|---|---|
| 連絡先 氏名 | テキスト | 必須 | レビュー問い合わせ対応者の氏名 |
| 連絡先 電話番号 | テキスト | 必須 | 日本の電話番号（+81形式） |
| 連絡先 メールアドレス | テキスト | 必須 | 開発者のメールアドレス |
| サインイン情報（ユーザー名） | テキスト | 条件付き | 不要（ログイン機能なし） |
| サインイン情報（パスワード） | テキスト | 条件付き | 不要（ログイン機能なし） |
| メモ（Notes） | テキスト（4,000文字） | 任意 | 「カメラアプリです。実機のカメラが必要です。写真・動画撮影の無音機能が主な特徴です。」 |
| 添付ファイル | ファイルアップロード | 任意 | アプリの操作デモ動画など（.mp4, .pdf等） |
| ルーティングアプリカバレッジファイル | .geojsonアップロード | 任意 | 不要（地域限定アプリではない） |

---

## 7. Appプライバシー（App Privacy）セクション

### 7-1. 最初の質問

| 質問 | 推奨回答 |
|---|---|
| あなたのアプリまたはサードパーティパートナーはデータを収集しますか？ | **いいえ**（広告SDK・分析SDK等を一切使用しない場合） |

※「いいえ」を選択した場合、以下のデータタイプ選択は不要。App Storeには「データ収集なし」と表示される。

### 7-2. データタイプ一覧（収集する場合のみ該当）

広告なし・分析SDKなし・サーバー通信なしの場合は全て「収集しない」でよい。
参考として全カテゴリを記載:

| データカテゴリ | サブカテゴリ | マナーカメラ4Kでの該当 |
|---|---|---|
| **連絡先情報** | 名前 | 収集しない |
| | メールアドレス | 収集しない |
| | 電話番号 | 収集しない |
| | 住所 | 収集しない |
| | その他の連絡先情報 | 収集しない |
| **健康とフィットネス** | 健康 | 収集しない |
| | フィットネス | 収集しない |
| **財務情報** | 支払い情報 | 収集しない |
| | クレジット情報 | 収集しない |
| | その他の財務情報 | 収集しない |
| **位置情報** | 正確な位置情報 | 収集しない※ |
| | おおよその位置情報 | 収集しない※ |
| **機密情報** | 人種・民族等 | 収集しない |
| **連絡先（アドレス帳）** | 連絡先 | 収集しない |
| **ユーザーコンテンツ** | メールまたはテキストメッセージ | 収集しない |
| | 写真またはビデオ | 収集しない（端末内のみ保存、サーバーに送信しない） |
| | オーディオデータ | 収集しない |
| | ゲームプレイコンテンツ | 収集しない |
| | カスタマーサポート | 収集しない |
| | その他のユーザーコンテンツ | 収集しない |
| **閲覧履歴** | 閲覧履歴 | 収集しない |
| **検索履歴** | 検索履歴 | 収集しない |
| **識別子** | ユーザーID | 収集しない |
| | デバイスID | 収集しない |
| **購入** | 購入履歴 | 収集しない |
| **使用状況データ** | 製品の操作 | 収集しない |
| | 広告データ | 収集しない |
| | その他の使用状況データ | 収集しない |
| **診断** | クラッシュデータ | 収集しない（Apple標準のクラッシュレポートはApple経由で処理） |
| | パフォーマンスデータ | 収集しない |
| | その他の診断データ | 収集しない |
| **その他のデータ** | その他 | 収集しない |

※ 位置情報について: 写真のExifメタデータに位置情報を埋め込む場合でも、そのデータはデバイス上の写真ファイルに保存されるだけでサーバーに送信しないため「収集しない」で正しい。

### 7-3. データの使用目的（収集する場合のみ）

各データタイプについて以下の使用目的を選択:
- サードパーティ広告
- デベロッパの広告またはマーケティング
- アナリティクス
- 製品のパーソナライズ
- アプリの機能

### 7-4. データリンクとトラッキング（収集する場合のみ）

- **ユーザーにリンクされるデータ**: ユーザーのアイデンティティに関連付けられるか
- **ユーザーにリンクされないデータ**: 匿名化されているか
- **トラッキングに使用**: サードパーティデータとリンクされるか

### 7-5. マナーカメラ 4K の推奨回答

**「データを収集しない」を選択**

理由:
- 広告SDKなし
- 分析SDKなし（Firebase Analytics等を使っていない場合）
- サーバー通信なし
- ユーザーデータをデバイス外に送信しない

App Storeには以下のように表示される:
> **データ収集なし**
> デベロッパはこのアプリからデータを収集しません。

---

## 8. リリース設定

| フィールド名 | 入力タイプ | 推奨入力値 |
|---|---|---|
| リリースオプション | 選択 | 「審査後に手動でリリース」または「審査承認後に自動でリリース」 |
| 段階的リリース（Phased Release） | 選択 | 新規アプリでは不要（アップデート時のオプション） |

---

## 9. 提出前チェックリスト

- [ ] Bundle ID が Xcode プロジェクトと一致
- [ ] ビルドが Xcode/Transporter 経由でアップロード済み
- [ ] 全スクリーンショットがアップロード済み（最低1枚/デバイスサイズ）
- [ ] プライバシーポリシーURLが有効でアクセス可能
- [ ] サポートURLが有効でアクセス可能
- [ ] 年齢制限の新アンケート（2025年7月版）に全回答済み
- [ ] Appプライバシー情報が設定済み
- [ ] 価格が設定済み
- [ ] Appレビュー情報（連絡先）が入力済み
- [ ] 説明文・キーワードが入力済み
- [ ] アプリアイコン（1024x1024）がビルドに含まれている
- [ ] Export Compliance（暗号化使用）の質問に回答済み

---

## 10. Export Compliance（輸出コンプライアンス）

ビルドアップロード後に表示される質問:

| 質問 | 推奨回答 | 理由 |
|---|---|---|
| アプリは暗号化を使用していますか？ | はい（HTTPS通信を使用する場合）/ いいえ（一切ネットワーク通信しない場合） | カメラアプリでネットワーク通信しない場合は「いいえ」 |
| 免除に該当しますか？ | はい（標準的なHTTPS/TLSのみの場合） | 独自暗号化がなければ免除 |

※ Info.plist に `ITSAppUsesNonExemptEncryption = NO` を設定しておくと毎回の質問をスキップできる。

---

Sources:
- [Apple Developer - Submitting](https://developer.apple.com/app-store/submitting/)
- [App Information Reference](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/)
- [Platform Version Information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/)
- [Age Ratings Values and Definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/)
- [Updated Age Ratings in App Store Connect](https://developer.apple.com/news/?id=ks775ehf)
- [Age Rating Updates - Upcoming Requirements](https://developer.apple.com/news/upcoming-requirements/?id=07242025a)
- [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)
- [Manage App Privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
- [App Pricing and Availability](https://developer.apple.com/help/app-store-connect/reference/pricing-and-availability/app-pricing-and-availability/)
- [App Review Information Reference](https://developer.apple.com/help/app-store-connect/reference/app-review-information/)
- [Required, Localizable, and Editable Properties](https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties/)
- [Screenshot Specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [9to5Mac - Apple new age rating system](https://9to5mac.com/2025/07/24/apple-notifies-developers-of-new-app-store-age-rating-system/)
- [ASO World - Age Rating Developer Guide](https://asoworld.com/blog/apple-app-store-age-rating-update-developer-guide/)
- [Capgo - App Store Age Ratings Guide](https://capgo.app/blog/app-store-age-ratings-guide/)
- [TechCrunch - Apple broadens age-rating system](https://techcrunch.com/2025/07/25/apple-broadens-app-stores-age-rating-system/)
