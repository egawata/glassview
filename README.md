# Transparent Window Capture

macOS上で他のアプリケーションのウィンドウをリアルタイムでキャプチャし、半透明のウィンドウで表示するSwiftアプリケーションです。

## 主な機能

- **リアルタイムウィンドウキャプチャ**: 選択した他のアプリケーションのウィンドウを30FPSでリアルタイム表示
- **半透明ウィンドウ**: アプリケーション自体のウィンドウを半透明に設定可能（透明度をスライダーで調整）
- **常に手前表示**: アプリケーションウィンドウを他のアプリより常に手前に表示する機能
- **クリック透過機能**:
  - 全体クリック無視: ウィンドウ全体のクリックを透過
  - キャプチャ部のみクリック無視: キャプチャ表示部分のみクリックを透過
- **メニューバー統合**: システムメニューバーからのアクセス
- **ウィンドウ選択**: 現在開いているすべてのウィンドウから任意のウィンドウを選択可能

## 必要要件

- **macOS 12.3以上** (ScreenCaptureKit フレームワーク使用のため)
- **Swift 5.9以上**
- **スクリーン録画権限** (システム設定で許可が必要)

## セットアップ

### 1. リリースビルドの作成

```bash
swift build --configuration release
```

### 2. アプリケーションバンドル（.app）の作成

```bash
# 最新のコードをビルドシステムに反映
cp Sources/TransparentWindowCapture/main.swift TransparentWindowCapture/main.swift

# リリースビルド実行
swift build --configuration release

# 既存のアプリバンドルをバックアップ（初回は不要）
mv TransparentWindowCapture.app TransparentWindowCapture.app.old 2>/dev/null || true

# 新しいアプリバンドル構造を作成
mkdir -p TransparentWindowCapture.app/Contents/{MacOS,Resources}

# 実行可能ファイルをコピー
cp .build/release/TransparentWindowCapture TransparentWindowCapture.app/Contents/MacOS/

# Info.plistを作成（自動生成済み）

# コード署名を適用
codesign --force --sign - --entitlements TransparentWindowCapture/TransparentWindowCapture.entitlements TransparentWindowCapture.app

# 実行権限を設定
chmod +x TransparentWindowCapture.app/Contents/MacOS/TransparentWindowCapture
```

### 3. アプリケーションの起動

```bash
# Finderからアイコンで起動（推奨）
open TransparentWindowCapture.app

# または、コマンドラインから直接実行
./.build/release/TransparentWindowCapture
```

### 4. 権限設定

## 使用方法

## 使用方法

1. **アプリケーションを起動**
   - Finderで `TransparentWindowCapture.app` をダブルクリック
   - または `open TransparentWindowCapture.app` コマンドで起動

2. **メニューバーからアクセス**
   - アプリケーション起動後、メニューバーに🎥アイコンが表示されます
   - アイコンをクリックしてメニューから「ウィンドウを表示」を選択

3. **ウィンドウキャプチャの開始**
   - ドロップダウンメニューから表示したいウィンドウを選択
   - 「キャプチャ開始」ボタンをクリック

4. **各種機能の設定**
   - **透明度調整**: スライダーでアプリケーションウィンドウの透明度を調整
   - **常に手前表示**: 「常に手前表示」ボタンまたはメニューバーから切り替え
   - **クリック透過**:
     - 「全体クリック無視」: ウィンドウ全体のクリックを透過
     - 「キャプチャ部のみ無視」: キャプチャ表示部分のみクリックを透過

5. **キャプチャの停止**
   - 「キャプチャ停止」ボタンをクリック

6. **アプリケーションの終了**
   - メニューバーアイコンから「終了」を選択
   - またはウィンドウを閉じる

## コードを変更した後の更新手順

機能を追加・修正した場合は、以下の手順でアプリケーションを更新してください：

```bash
# 1. 最新のコードをビルドシステムに反映
cp Sources/TransparentWindowCapture/main.swift TransparentWindowCapture/main.swift

# 2. リリースビルド
swift build --configuration release

# 3. 実行中のアプリを停止
pkill -f "TransparentWindowCapture" 2>/dev/null || true

# 4. 実行可能ファイルを更新
cp .build/release/TransparentWindowCapture TransparentWindowCapture.app/Contents/MacOS/

# 5. 再コード署名
codesign --force --sign - --entitlements TransparentWindowCapture/TransparentWindowCapture.entitlements TransparentWindowCapture.app

# 6. アプリ起動
open TransparentWindowCapture.app
```

### ワンライナー更新コマンド

開発中によく使う更新作業をワンライナーでまとめました：

```bash
# 最新コードでアプリを更新して起動
cp Sources/TransparentWindowCapture/main.swift TransparentWindowCapture/main.swift && swift build --configuration release && pkill -f "TransparentWindowCapture" 2>/dev/null || true && cp .build/release/TransparentWindowCapture TransparentWindowCapture.app/Contents/MacOS/ && codesign --force --sign - --entitlements TransparentWindowCapture/TransparentWindowCapture.entitlements TransparentWindowCapture.app && open TransparentWindowCapture.app
```

## 機能の使用シナリオ例

### パターン1: オーバーレイ表示
- **常に手前表示**: ✅ ON
- **クリックスルー**: ❌ OFF
- **用途**: 常にモニターしたい情報を表示しつつ、必要時にアプリを操作

### パターン2: 透明オーバーレイ
- **常に手前表示**: ✅ ON
- **全体クリックスルー**: ✅ ON
- **用途**: 参考情報を表示しながら、下のアプリを完全に操作

### パターン3: ハイブリッドモード
- **常に手前表示**: ✅ ON
- **部分クリックスルー**: ✅ ON
- **用途**: キャプチャ内容は透過、コントロール部分は操作可能

## 技術仕様

### 使用フレームワーク
- **AppKit**: macOSネイティブUI
- **ScreenCaptureKit**: 高性能ウィンドウキャプチャ
- **CoreImage**: 画像処理

### アーキテクチャ
- **AppDelegate**: アプリケーションライフサイクル管理とメニューバー統合
- **WindowCaptureManager**: ScreenCaptureKitを使用したキャプチャ管理
- **ViewController**: UI制御、半透明効果、常に手前表示、クリック透過の管理
- **ClickThroughImageView**: クリック透過機能を持つカスタムImageView

### キャプチャ仕様
- フレームレート: 30 FPS
- ピクセルフォーマット: 32-bit BGRA
- キューデプス: 3フレーム

## 注意事項

- アプリケーションにはスクリーン録画権限が必要です
- 自分自身のアプリケーションウィンドウはキャプチャ対象から除外されます
- macOS 12.3未満では動作しません
- サンドボックス環境では制限される場合があります

## トラブルシューティング

### アプリケーションが起動直後に終了する場合
- **原因**: スクリーン録画権限が許可されていない
- **解決方法**:
  1. システム設定 > プライバシーとセキュリティ > スクリーン録画
  2. TransparentWindowCaptureアプリをチェック
  3. アプリケーションを再起動

### メニューバーにアイコンが表示されない場合
- アプリケーションが正常に起動しているか確認
- システム設定でメニューバーアイコンの表示が制限されていないか確認

### ウィンドウが表示されない場合
- スクリーン録画権限が許可されているか確認してください
- 対象アプリケーションが実際にウィンドウを表示しているか確認してください

### キャプチャが開始されない場合
- ウィンドウリストを更新してみてください（「更新」ボタンをクリック）
- 対象ウィンドウが最小化されていないか確認してください

## 開発者向け情報

### プロジェクト構造
```
TransparentWindowCapture/
├── TransparentWindowCapture/
│   ├── main.swift                           # メインアプリケーションファイル
│   ├── Info.plist                          # アプリケーション情報
│   ├── TransparentWindowCapture.entitlements  # アプリ権限設定
│   └── Assets.xcassets/                    # アプリアイコンとアセット
├── TransparentWindowCapture.app/           # 実行可能なアプリケーションバンドル
├── Sources/
│   └── TransparentWindowCapture/
│       └── main.swift                      # 元のモノリシックファイル
├── Package.swift                           # Swift Package Manager設定
└── README.md
```

### 拡張可能性
- 複数ウィンドウの同時キャプチャ
- 録画機能の追加
- キャプチャ画像の保存機能
- ホットキーによる操作

## ライセンス

このプロジェクトはMITライセンスの下で公開されています。
