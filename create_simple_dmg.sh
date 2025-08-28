#!/bin/bash

# 簡単なDMG作成スクリプト（背景画像なし版）
# より簡単で確実な方法

set -e

# 変数定義
APP_NAME="GlassView"
VERSION="1.0"
FINAL_DMG="${APP_NAME}-${VERSION}.dmg"
APP_PATH="GlassView.app"

echo "🚀 ${APP_NAME} v${VERSION} のDMG作成を開始します..."

# 既存のDMGを削除
rm -f "${FINAL_DMG}"

# アプリケーションが存在するか確認
if [ ! -d "${APP_PATH}" ]; then
    echo "❌ エラー: ${APP_PATH} が見つかりません"
    exit 1
fi

echo "📦 DMGを作成中..."

# hdiutil createを使用してDMGを直接作成
hdiutil create -volname "${APP_NAME}" -srcfolder "${APP_PATH}" -ov -format UDZO "${FINAL_DMG}"

echo "✅ DMG作成完了!"
echo "📁 作成されたファイル: $(pwd)/${FINAL_DMG}"
echo "📏 ファイルサイズ: $(du -h "${FINAL_DMG}" | cut -f1)"

# DMGを開く
open "${FINAL_DMG}"

echo "🎉 完了！"
