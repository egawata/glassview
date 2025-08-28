# DMGインストーラー作成方法

このプロジェクトには、macOSアプリケーション用のDMGインストーラーを作成するための複数のスクリプトが含まれています。

## 利用可能なスクリプト

### 1. create_simple_dmg.sh（推奨）
最も簡単で確実な方法です。アプリケーションバンドルをそのままDMGに変換します。

```bash
./create_simple_dmg.sh
```

**特徴:**
- 依存関係なし
- 高速作成
- 確実に動作

### 2. create_professional_dmg.sh
より洗練されたDMGを作成します。Applicationフォルダへのリンクやレイアウト設定が含まれます。

```bash
# 事前にcreate-dmgをインストール（初回のみ）
brew install create-dmg

# DMG作成
./create_professional_dmg.sh
```

**特徴:**
- ユーザーフレンドリーなレイアウト
- Applicationフォルダへのドラッグ&ドロップリンク
- プロフェッショナルな見た目

### 3. create_dmg.sh
最もカスタマイズ性の高いスクリプトです。背景画像やウィンドウレイアウトの詳細設定が可能です。

```bash
./create_dmg.sh
```

**特徴:**
- 完全なカスタマイズ性
- 背景画像対応
- 詳細なウィンドウレイアウト設定

## 作成前の準備

1. アプリケーションをビルド済みであることを確認：
   ```bash
   ls -la TransparentWindowCapture.app/Contents/MacOS/TransparentWindowCapture
   ```

2. 必要に応じて依存ツールをインストール：
   ```bash
   # create-dmg（professional版を使用する場合）
   brew install create-dmg
   ```

## 作成されるファイル

- `GlassView-1.0.dmg` - 配布用DMGファイル

### 注意点
- ファイルサイズ: 約450KB-870KB（スクリプトにより異なる）

## 配布方法

作成されたDMGファイルを以下の方法で配布できます：

1. **GitHub Releases** - リポジトリのReleasesページにアップロード
2. **直接配布** - DMGファイルをウェブサイトやメールで配布
3. **Mac App Store** - 正式な配布（Apple Developer Programが必要）

## カスタマイズ

各スクリプトの変数部分を編集することで、以下をカスタマイズできます：

- アプリケーション名
- バージョン番号
- DMGファイル名
- ウィンドウレイアウト（professional版）

## トラブルシューティング

### スクリプト実行権限エラー
```bash
chmod +x create_simple_dmg.sh create_professional_dmg.sh create_dmg.sh
```

### create-dmgが見つからない
```bash
brew install create-dmg
```

### 既存のDMGファイルが削除できない
```bash
rm -f GlassView-*.dmg
./create_simple_dmg.sh
```

## 推奨ワークフロー

1. **開発・テスト段階**: `create_simple_dmg.sh`を使用
2. **リリース準備**: `create_professional_dmg.sh`を使用
3. **特別なカスタマイズが必要**: `create_dmg.sh`を使用
