#!/bin/bash

# プロフェッショナルなDMG作成スクリプト
# create-dmg ツールを使用（要インストール: brew install create-dmg）

set -e

# 変数定義
APP_NAME="GlassView"
VERSION="v0.2"
FINAL_DMG="${APP_NAME}-${VERSION}.dmg"
APP_PATH="GlassView.app"

echo "🚀 ${APP_NAME} v${VERSION} のプロフェッショナルDMG作成を開始します..."

# create-dmgがインストールされているか確認
if ! command -v create-dmg &> /dev/null; then
    echo "❌ create-dmg がインストールされていません"
    echo "以下のコマンドでインストールしてください："
    echo "brew install create-dmg"
    exit 1
fi

# アプリケーションが存在するか確認
if [ ! -d "${APP_PATH}" ]; then
    echo "❌ エラー: ${APP_PATH} が見つかりません"
    exit 1
fi

# 既存のDMGを削除
rm -f "${FINAL_DMG}"

echo "📦 プロフェッショナルDMGを作成中..."

# create-dmgを使用してDMGを作成
create-dmg \
  --volname "${APP_NAME}" \
  --window-pos 200 120 \
  --window-size 600 300 \
  --icon-size 100 \
  --icon "${APP_NAME}.app" 175 120 \
  --hide-extension "${APP_NAME}.app" \
  --app-drop-link 425 120 \
  "${FINAL_DMG}" \
  "${APP_PATH}"

echo "✅ プロフェッショナルDMG作成完了!"
echo "📁 作成されたファイル: $(pwd)/${FINAL_DMG}"
echo "📏 ファイルサイズ: $(du -h "${FINAL_DMG}" | cut -f1)"

# DMGを開く
open "${FINAL_DMG}"

echo "🎉 完了！"
