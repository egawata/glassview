#!/bin/bash

# GlassView DMG作成スクリプト
# 実行前に chmod +x create_dmg.sh でスクリプトに実行権限を与えてください

set -e  # エラー時に停止

# 変数定義
APP_NAME="GlassView"
VERSION="1.0"
DMG_NAME="${APP_NAME}-${VERSION}"
FINAL_DMG="${DMG_NAME}.dmg"
TEMP_DMG="temp_${DMG_NAME}.dmg"
MOUNT_POINT="/tmp/${APP_NAME}_dmg"
APP_PATH="GlassView.app"

echo "🚀 ${APP_NAME} v${VERSION} のDMG作成を開始します..."

# 既存のDMGファイルを削除
if [ -f "${FINAL_DMG}" ]; then
    echo "🗑️  既存のDMGファイル ${FINAL_DMG} を削除します..."
    rm -f "${FINAL_DMG}"
fi

if [ -f "${TEMP_DMG}" ]; then
    echo "🗑️  既存の一時DMGファイル ${TEMP_DMG} を削除します..."
    rm -f "${TEMP_DMG}"
fi

# アプリケーションバンドルが存在するか確認
if [ ! -d "${APP_PATH}" ]; then
    echo "❌ エラー: ${APP_PATH} が見つかりません"
    echo "まず、アプリケーションをビルドしてください"
    exit 1
fi

# 一時マウントポイントをクリーンアップ
if [ -d "${MOUNT_POINT}" ]; then
    echo "🧹 既存のマウントポイントをクリーンアップします..."
    umount "${MOUNT_POINT}" 2>/dev/null || true
    rm -rf "${MOUNT_POINT}"
fi

echo "📦 一時DMGを作成中..."
# 100MBの一時DMGを作成（アプリサイズに応じて調整可能）
hdiutil create -size 100m -fs HFS+ -volname "${APP_NAME}" "${TEMP_DMG}"

echo "🔗 DMGをマウント中..."
# DMGをマウント
mkdir -p "${MOUNT_POINT}"
hdiutil attach "${TEMP_DMG}" -mountpoint "${MOUNT_POINT}"

echo "📂 ファイルをコピー中..."
# アプリケーションをDMGにコピー
cp -R "${APP_PATH}" "${MOUNT_POINT}/"

# Applicationsフォルダへのシンボリックリンクを作成
ln -s /Applications "${MOUNT_POINT}/Applications"

# README.mdがあればコピー
if [ -f "README.md" ]; then
    cp "README.md" "${MOUNT_POINT}/"
fi

# LICENSEファイルがあればコピー
if [ -f "LICENSE" ]; then
    cp "LICENSE" "${MOUNT_POINT}/"
fi

echo "💎 DMGの見た目を設定中..."
# DMGのウィンドウ設定を作成（Appleスクリプトを使用）
osascript <<EOF
tell application "Finder"
    tell disk "${APP_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 920, 420}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 72
        set background picture of viewOptions to file ".background:background.png"
        set position of item "GlassView.app" of container window to {160, 205}
        set position of item "Applications" of container window to {360, 205}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

echo "💾 変更を同期中..."
# 変更を確実に書き込み
sync

echo "🔄 DMGをアンマウント中..."
# DMGをアンマウント
hdiutil detach "${MOUNT_POINT}"

echo "🗜️  最終DMGを圧縮作成中..."
# 最終的な読み取り専用DMGを作成
hdiutil convert "${TEMP_DMG}" -format UDZO -o "${FINAL_DMG}"

echo "🧹 一時ファイルをクリーンアップ中..."
# 一時ファイルを削除
rm -f "${TEMP_DMG}"
rm -rf "${MOUNT_POINT}"

echo "✅ DMG作成完了!"
echo "📁 作成されたファイル: $(pwd)/${FINAL_DMG}"
echo "📏 ファイルサイズ: $(du -h "${FINAL_DMG}" | cut -f1)"

# DMGを開く（オプション）
read -p "🔍 作成されたDMGを開きますか？ (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "${FINAL_DMG}"
fi

echo "🎉 DMG作成プロセスが完了しました！"
