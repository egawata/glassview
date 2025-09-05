# GlassView

macOS上で他のアプリケーションのウィンドウをリアルタイムでキャプチャし、透過ウィンドウで表示するSwiftアプリケーションです。

## 必要要件

- macOS 12.3以上

## インストール

### dmg からインストール

https://github.com/egawata/glassview/releases/tag/v0.1 から `.dmg` ファイルをダウンロードし、インストールを行ってください。

### ソースコードからビルド

#### 方法 1: Swift Package Manager を使用（推奨）

~~~sh
# Swift Package Manager でビルド
swift build -c release
pkill -9 -f "TransparentWindowCapture\|GlassView" 2>/dev/null || true
rm -rf GlassView.app
cp -R /Users/$(whoami)/Library/Developer/Xcode/DerivedData/TransparentWindowCapture-*/Build/Products/Release/GlassView.app . 2>/dev/null || mkdir -p GlassView.app/Contents/{MacOS,Resources}
cp .build/release/GlassView GlassView.app/Contents/MacOS/
cp TransparentWindowCapture/Info.plist GlassView.app/Contents/
codesign --force --sign - --entitlements TransparentWindowCapture/TransparentWindowCapture.entitlements GlassView.app
~~~

#### 方法 2: Xcode ビルドシステムを使用

~~~sh
xcodebuild -project TransparentWindowCapture.xcodeproj -scheme TransparentWindowCapture -configuration Release clean build
tccutil reset ScreenCapture com.example.TransparentWindowCapture
rm -rf GlassView.app
cp -R /Users/$(whoami)/Library/Developer/Xcode/DerivedData/TransparentWindowCapture-*/Build/Products/Release/GlassView.app .
~~~

### 権限設定

初回起動時に、システムから `スクリーン録画` 権限の許可を求められます：

- ダイアログで `システム設定を開く`をクリック
- `GlassView` にチェックを入れる
- アプリケーションを再起動

## 使用方法

### 基本操作

アプリケーションを起動すると、メインウィンドウ（キャプチャ表示用）と**コントロールパネル**（操作用）の2つのウィンドウが表示されます。

**コントロールパネルでの操作:**
- **ウィンドウ選択プルダウン**: キャプチャ対象のウィンドウを選択します
- **キャプチャ開始/停止**: キャプチャ中は元のウィンドウの表示内容がリアルタイムに反映されます
- **リスト更新**: 表示できるウィンドウのリストを更新します
- **不透明度**: メインウィンドウの不透明度を変更します
- **fps**: 更新頻度を調整します。値が大きいほどリアルタイム性が増しますが、CPU負荷が上がります
- **クリック透過**: メインウィンドウがマウス操作に反応せず、背後のアプリケーションに伝わるようになります
- **常に手前表示**: メインウィンドウが常に最前面に表示されます
- **全てリセット**: すべての設定を初期値にリセットします

**コントロールパネルの特徴:**
- コントロールパネルは不透明度やクリック透過の設定に影響されません
- 常に操作可能な状態を保ち、設定変更やアプリケーション制御が可能です
- 「常に手前表示」の設定はコントロールパネルにも適用されます

### メニュー操作

デスクトップ最上部のアイコンからメニューにアクセスできます。

- **全てリセット**: クリック透過、最前面表示、不透明度の変更がすべてリセットされます。
   - 設定を変更しすぎてウィンドウの操作が難しくなったときに使用してください
- **常に手前に表示**: 最前面表示の有効/無効を切り替えます
- **クリック透過**: クリック透過の有効/無効を切り替えます
- **不透明度リセット**: 不透明度を100%にリセットします

## トラブルシューティング

### CPU 負荷が高い、なんかマシンの動作が重い

- 画面更新の頻度を下げることで負荷が下がります。
- fps を下げてみてください。たいていの用途では 5fps 以下で十分なはずです。
- 画面更新が必要なければ、キャプチャ開始後に `キャプチャ停止` を押して画面更新を止めてください。


## 開発者向け情報

機能を追加・修正した場合は、以下の手順でアプリケーションを更新してください：

### 方法 1: Swift Package Manager を使用（推奨）

```bash
# 1. リリースビルド
swift build -c release

# 2. 実行中のアプリを停止
pkill -f "TransparentWindowCapture\|GlassView" 2>/dev/null || true

# 3. 実行可能ファイルを更新
cp .build/release/GlassView GlassView.app/Contents/MacOS/

# 4. 再コード署名
codesign --force --sign - --entitlements TransparentWindowCapture/TransparentWindowCapture.entitlements GlassView.app

# 5. アプリ起動
open GlassView.app
```

### 方法 2: Xcode ビルドシステムを使用

```bash
# 1. リリースビルド
xcodebuild -project TransparentWindowCapture.xcodeproj -scheme TransparentWindowCapture -configuration Release clean build

# 2. 実行中のアプリを停止
pkill -f "TransparentWindowCapture" 2>/dev/null || true

# 3. 実行可能ファイルを更新
cp .build/release/TransparentWindowCapture GlassView.app/Contents/MacOS/

# 4. 再コード署名
codesign --force --sign - --entitlements TransparentWindowCapture/TransparentWindowCapture.entitlements GlassView.app

# 5. アプリ起動
open GlassView.app
```

### ワンライナー更新コマンド

開発中によく使う更新作業をワンライナーでまとめました：

#### Swift Package Manager を使用（推奨）

```bash
# 最新コードでアプリを更新して起動（Swift Package Manager使用）
swift build -c release &&
pkill -9 -f "TransparentWindowCapture\|GlassView" 2>/dev/null || true &&
cp .build/release/GlassView GlassView.app/Contents/MacOS/ &&
codesign --force --sign - --entitlements TransparentWindowCapture/TransparentWindowCapture.entitlements GlassView.app &&
sleep 1 &&
open GlassView.app
```

#### Xcodeビルドシステムを使用

```bash
# 最新コードでアプリを更新して起動（Xcodeビルドシステム使用）
xcodebuild -project TransparentWindowCapture.xcodeproj -scheme TransparentWindowCapture -configuration Release clean build &&
pkill -9 -f "TransparentWindowCapture" 2>/dev/null || true &&
rm -rf GlassView.app &&
cp -R /Users/$(whoami)/Library/Developer/Xcode/DerivedData/TransparentWindowCapture-*/Build/Products/Release/GlassView.app . &&
sleep 1 &&
open GlassView.app
```

**注意**: コード署名エラーが発生する場合は、以下の代替手順を試してください：

```bash
# コード署名エラーの対処版
xcodebuild -project TransparentWindowCapture.xcodeproj -scheme TransparentWindowCapture -configuration Release clean build &&
pkill -9 -f "TransparentWindowCapture" 2>/dev/null || true &&
rm -rf GlassView.app &&
cp -R /Users/$(whoami)/Library/Developer/Xcode/DerivedData/TransparentWindowCapture-*/Build/Products/Release/GlassView.app . &&
codesign --force --sign - --deep GlassView.app &&
sleep 1 &&
open GlassView.app
```

### スクリーン録画権限の問題

#### 症状
- 「更新」ボタンを押すたびにシステム設定を行うよう促すダイアログが表示される
- ウィンドウ一覧が取得できない
- アプリケーションが起動直後に終了する

#### 解決方法
1. **システム設定での権限確認**:
   ```bash
   # システム設定を直接開く
   open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
   ```
   - `GlassView` または `TransparentWindowCapture` を探してチェックを入れる

2. **権限のリセット**（問題が続く場合）:
   ```bash
   # 権限をリセット
   tccutil reset ScreenCapture com.example.TransparentWindowCapture

   # アプリケーションを再起動
   open GlassView.app
   ```

3. **完全リセット手順**:
   ```bash
   # アプリを完全停止
   pkill -9 -f "TransparentWindowCapture"

   # 権限リセット
   tccutil reset ScreenCapture com.example.TransparentWindowCapture

   # アプリ再署名
   codesign --force --sign - --entitlements TransparentWindowCapture/TransparentWindowCapture.entitlements GlassView.app

   # アプリ起動
   open GlassView.app
   ```

## ライセンス

このプロジェクトはApache License 2.0の下で公開されています。詳細については[LICENSE](LICENSE)ファイルをご覧ください。
