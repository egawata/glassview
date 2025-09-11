/*
Copyright 2025 egawata

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import AppKit
import ScreenCaptureKit
import os.log

// MARK: - ViewController
@available(macOS 12.3, *)
class ViewController: NSViewController {
    // UI Components
    private var customImageView: ClickThroughImageView!

    // Tips display components
    private var tipsContainerView: NSView!
    private var tipsLabel: NSTextField!
    private var tipsImageView: NSImageView!

    // Properties
    private var windowCaptureManager: WindowCaptureManager?
    private var isClickThroughEnabled = false
    private var isAlwaysOnTopEnabled = false
    private var currentFrameRate: Double = 3.0  // initial fps

    private let logger = Logger(subsystem: "com.example.GlassView", category: "ViewController")

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        setupUI()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupWindowTransparency()
        setupWindowCaptureManager()
        setupKeyboardShortcuts()

        // ウィンドウリサイズの監視を設定
        setupWindowResizeObserver()
    }

    // MARK: - Keyboard Shortcuts Setup
    private func setupKeyboardShortcuts() {
        // メニューベースのキーボードショートカットを設定
        setupMenuShortcuts()

        // 代替として、より確実なイベント監視も設定
        setupEventMonitor()
    }

    private func setupMenuShortcuts() {
        guard let window = view.window else { return }

        // ウィンドウ用の隠しメニューを作成
        let menu = NSMenu()

        // 拡大
        let zoomInItem = NSMenuItem(title: "Zoom In", action: #selector(menuZoomIn), keyEquivalent: "+")
        zoomInItem.target = self
        zoomInItem.keyEquivalentModifierMask = .command
        menu.addItem(zoomInItem)

        // 縮小
        let zoomOutItem = NSMenuItem(title: "Zoom Out", action: #selector(menuZoomOut), keyEquivalent: "-")
        zoomOutItem.target = self
        zoomOutItem.keyEquivalentModifierMask = .command
        menu.addItem(zoomOutItem)

        // リセット
        let resetItem = NSMenuItem(title: "Reset Zoom", action: #selector(menuResetZoom), keyEquivalent: "n")
        resetItem.target = self
        resetItem.keyEquivalentModifierMask = .command
        menu.addItem(resetItem)

        // ウィンドウにメニューを関連付け（見えないメニュー）
        window.menu = menu
    }

    private func setupEventMonitor() {
        // より確実なキーイベント監視（バックアップ用）
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyDownEvent(event) == true {
                return nil // イベントを消費
            }
            return event
        }
    }

    private func handleKeyDownEvent(_ event: NSEvent) -> Bool {
        let modifierFlags = event.modifierFlags

        // Commandキーが押されているかチェック
        guard modifierFlags.contains(.command) else { return false }

        // 他の修飾キーは無視（ShiftやOptionなど）
        let cleanModifiers = modifierFlags.intersection([.command])
        guard cleanModifiers == .command else { return false }

        switch event.charactersIgnoringModifiers?.lowercased() {
        case "+", "=":
            customImageView.zoomIn()
            return true
        case "-":
            customImageView.zoomOut()
            return true
        case "n":
            customImageView.resetTransform()
            return true
        default:
            return false
        }
    }

    // MARK: - Menu Actions
    @objc private func menuZoomIn() {
        customImageView.zoomIn()
    }

    @objc private func menuZoomOut() {
        customImageView.zoomOut()
    }

    @objc private func menuResetZoom() {
        customImageView.resetTransform()
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        let modifierFlags = event.modifierFlags
        let keyCode = event.keyCode

        // Command + Plus (拡大)
        if modifierFlags.contains(.command) && (keyCode == 24 || event.charactersIgnoringModifiers == "=") {
            customImageView.zoomIn()
            return nil // イベントを消費
        }

        // Command + Minus (縮小)
        if modifierFlags.contains(.command) && (keyCode == 27 || event.charactersIgnoringModifiers == "-") {
            customImageView.zoomOut()
            return nil // イベントを消費
        }

        // Command + N (リセット)
        if modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "n" {
            customImageView.resetTransform()
            return nil // イベントを消費
        }

        return event // その他のイベントはそのまま通す
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        // ビューのレイアウトが変更された時にキャプチャエリアのサイズも調整
        updateCaptureAreaLayout()
    }

    private func setupUI() {
        // クリッピング用のコンテナビューを作成
        let containerView = NSView(frame: NSRect(x: 20, y: 20, width: 760, height: 560))
        containerView.wantsLayer = true
        containerView.layer?.masksToBounds = true // クリッピングを有効化
        containerView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        view.addSubview(containerView)

        // Custom ImageView (click-through capable) - コンテナ内に配置
        customImageView = ClickThroughImageView(frame: NSRect(x: 0, y: 0, width: 760, height: 560))
        customImageView.imageScaling = .scaleNone // 自動スケーリングを無効化
        customImageView.imageAlignment = .alignCenter
        customImageView.wantsLayer = true
        customImageView.layer?.backgroundColor = NSColor.clear.cgColor
        containerView.addSubview(customImageView) // コンテナビューに追加

        // Setup Tips container
        setupTipsDisplay()
    }

    // MARK: - Tips Display Setup
    private func setupTipsDisplay() {
        // Tips container view (centered in capture area)
        let containerWidth: CGFloat = 700
        let containerHeight: CGFloat = 350
        let containerX = customImageView.frame.midX - (containerWidth / 2)
        let containerY = customImageView.frame.midY - (containerHeight / 2)

        tipsContainerView = NSView(frame: NSRect(x: containerX, y: containerY, width: containerWidth, height: containerHeight))
        tipsContainerView.wantsLayer = true
        tipsContainerView.layer?.backgroundColor = NSColor.clear.cgColor

        // Tips label
        tipsLabel = NSTextField(frame: NSRect(x: 50, y: 220, width: 600, height: 90))
        tipsLabel.stringValue = "[TIPS]\n拡大縮小: `Shift` キーを押しながらマウスホイールを操作\n移動: `Space` キーを押しながらマウス左ドラッグ"
        tipsLabel.isEditable = false
        tipsLabel.isBordered = false
        tipsLabel.backgroundColor = NSColor.clear
        tipsLabel.textColor = NSColor.secondaryLabelColor
        tipsLabel.font = NSFont.systemFont(ofSize: 16)
        tipsLabel.alignment = .center
        tipsLabel.maximumNumberOfLines = 3
        tipsLabel.cell?.wraps = true
        tipsLabel.cell?.isScrollable = false

        // Tips image view
        tipsImageView = NSImageView(frame: NSRect(x: 200, y: 40, width: 300, height: 140))
        if let tipsImage = NSImage(named: "TipsResetImage") {
            tipsImageView.image = tipsImage
        } else if let tipsImage = loadTipsImageFromBundle() {
            tipsImageView.image = tipsImage
        } else {
            tipsImageView.image = NSImage(systemSymbolName: "arrow.clockwise.circle", accessibilityDescription: "Reset")
        }
        tipsImageView.imageScaling = .scaleProportionallyUpOrDown
        tipsImageView.imageAlignment = .alignCenter

        // Add subviews to container
        tipsContainerView.addSubview(tipsLabel)
        // tipsContainerView.addSubview(tipsImageView)  // 画像は非表示

        // Add container to custom image view
        customImageView.addSubview(tipsContainerView)
    }

    // Helper method to load tips image from bundle resources (fallback only)
    private func loadTipsImageFromBundle() -> NSImage? {
        // バンドルリソースから画像を読み込み（プライマリは Assets.xcassets から）
        if let resourcePath = Bundle.main.path(forResource: "tips_reset", ofType: "png"),
           let image = NSImage(contentsOfFile: resourcePath) {
            return image
        }

        // fallback for dev env
        if let image = NSImage(contentsOfFile: "images/tips_reset.png") {
            return image
        }

        return nil
    }

    // MARK: - Tips Display Control
    private func showTipsDisplay() {
        tipsContainerView?.isHidden = false
        tipsContainerView?.alphaValue = 1.0
    }

    private func hideTipsDisplay() {
        // Animate fade out
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            tipsContainerView?.animator().alphaValue = 0.0
        } completionHandler: {
            self.tipsContainerView?.isHidden = true
        }
    }

    func showTips() {
        showTipsDisplay()
    }

    // MARK: - State Management Methods (called from Control Panel)
    func resetAllToInitialState() {
        // 不透明度を初期値にリセット
        updateWindowTransparency(1.0)

        // クリック透過を無効化
        updateClickThroughState(false)

        // 常に手前表示を無効化
        updateAlwaysOnTopState(false)

        // フレームレートはリセット対象外（現在の値を維持）

        // キャプチャは継続したまま（停止しない）
    }

    func updateClickThroughState(_ enabled: Bool) {
        isClickThroughEnabled = enabled
        (view.window as? ClickThroughWindow)?.setGlobalClickThroughEnabled(isClickThroughEnabled)
        customImageView?.setClickThroughEnabled(false)
    }

    func updateAlwaysOnTopState(_ enabled: Bool) {
        isAlwaysOnTopEnabled = enabled
        view.window?.level = isAlwaysOnTopEnabled ? .floating : .normal
    }

    func updateWindowTransparency(_ alphaValue: Double) {
        view.window?.alphaValue = CGFloat(alphaValue)
    }

    func startCapture(for window: SCWindow, frameRate: Double) {
        windowCaptureManager?.startCapture(for: window, frameRate: frameRate)
        hideTipsDisplay()
    }

    func stopCapture() {
        windowCaptureManager?.stopCapture()
    }

    func updateFrameRate(_ frameRate: Double) {
        currentFrameRate = frameRate
        windowCaptureManager?.updateFrameRate(frameRate)
    }

    private func setupWindowTransparency() {
        view.window?.isOpaque = false
        view.window?.backgroundColor = NSColor.clear
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.9).cgColor
    }

    private func setupWindowCaptureManager() {
        windowCaptureManager = WindowCaptureManager()
        windowCaptureManager?.delegate = self

        // ビューが読み込まれた後にターゲットウィンドウを設定
        DispatchQueue.main.async { [weak self] in
            if let window = self?.view.window {
                self?.windowCaptureManager?.setTargetWindow(window)
            }
        }
    }

    // MARK: - Window Resize and Layout Methods
    private func setupWindowResizeObserver() {
        // ウィンドウリサイズの通知を監視
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResize(_:)),
            name: NSWindow.didResizeNotification,
            object: view.window
        )
    }

    @objc private func windowDidResize(_ notification: Notification) {
        // ウィンドウがリサイズされた時にキャプチャエリアのレイアウトを更新
        updateCaptureAreaLayout()
    }

    private func updateCaptureAreaLayout() {
        guard let window = view.window else { return }

        // 画像が設定されていない場合は処理をスキップ
        guard customImageView.image != nil else {
            #if DEBUG
            print("⚠️ updateCaptureAreaLayout: No image set, skipping layout update")
            #endif
            return
        }

        let windowFrame = window.contentView?.frame ?? NSRect.zero
        let margin: CGFloat = 20

        // 現在の拡大倍率と平行移動を取得
        let currentScale = customImageView.getCurrentScale()
        let currentTranslation = customImageView.getCurrentTranslation()

        // ImageViewの基本サイズ（拡大なし）を取得
        let imageSize = customImageView.image?.size ?? NSSize(width: 800, height: 600)

        // クリッピング用のコンテナビューを設定（ウィンドウサイズに合わせる）
        let visibleArea = NSRect(
            x: margin,
            y: margin,
            width: windowFrame.width - (margin * 2),
            height: windowFrame.height - (margin * 2)
        )

        // ImageViewのスーパービューにクリッピングを設定
        if let containerView = customImageView.superview {
            containerView.frame = visibleArea
            containerView.wantsLayer = true
            containerView.layer?.masksToBounds = true
        }

        // ImageViewのフレームは元画像サイズを維持（拡大はトランスフォームで処理）
        let imageViewFrame = NSRect(
            x: 0,  // コンテナ座標系で左上から開始
            y: 0,
            width: imageSize.width,
            height: imageSize.height
        )
        customImageView.frame = imageViewFrame

        // 拡大倍率と平行移動を再適用
        customImageView.setScale(currentScale)
        customImageView.setPanPosition(x: currentTranslation.x, y: currentTranslation.y)

        // Update tips container position
        updateTipsContainerLayout()

        // 現在の画像がある場合は再描画をトリガー
        if let currentImage = customImageView.image {
            customImageView.image = currentImage
            customImageView.needsDisplay = true
        }
    }

    private func updateTipsContainerLayout() {
        guard let tipsContainer = tipsContainerView else { return }

        // Recalculate tips container position centered in capture area - サイズを調整後の値に更新
        let containerWidth: CGFloat = 700  // setupTipsDisplay()と同じ値
        let containerHeight: CGFloat = 350  // setupTipsDisplay()と同じ値
        let containerX = (customImageView.frame.width - containerWidth) / 2
        let containerY = (customImageView.frame.height - containerHeight) / 2

        tipsContainer.frame = NSRect(x: containerX, y: containerY, width: containerWidth, height: containerHeight)
    }

    deinit {
        // メモリリークを防ぐためにNotificationObserverを削除
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Transform Methods
    func zoomIn() {
        customImageView.zoomIn()
    }

    func zoomOut() {
        customImageView.zoomOut()
    }

    func resetTransform() {
        customImageView.resetTransform()
    }
}

// MARK: - WindowCaptureManagerDelegate
@available(macOS 12.3, *)
extension ViewController: WindowCaptureManagerDelegate {
    func didReceiveNewFrame(_ image: NSImage) {
        DispatchQueue.main.async {
            let wasFirstImage = self.customImageView.image == nil

            // 画像をキャプチャエリアに設定
            self.customImageView.image = image

            // 初回の画像設定時は、適切なレイアウト調整を実行
            if wasFirstImage {
                self.setupInitialImageLayout(for: image)
            }
        }
    }

    // 初回画像設定時の適切なレイアウト設定
    private func setupInitialImageLayout(for image: NSImage) {
        guard let window = view.window else { return }

        let windowFrame = window.contentView?.frame ?? NSRect.zero
        let margin: CGFloat = 20

        // 表示可能エリアのサイズ
        let availableWidth = windowFrame.width - (margin * 2)
        let availableHeight = windowFrame.height - (margin * 2)

        // 画像の実際のサイズ
        let imageSize = image.size

        // 表示エリアに画像を適合させるための拡大率を計算
        let scaleToFitWidth = availableWidth / imageSize.width
        let scaleToFitHeight = availableHeight / imageSize.height
        let initialScale = min(scaleToFitWidth, scaleToFitHeight) // アスペクト比を保持

        // コンテナビューのフレーム設定
        if let containerView = customImageView.superview {
            containerView.frame = NSRect(x: margin, y: margin, width: availableWidth, height: availableHeight)
            containerView.wantsLayer = true
            containerView.layer?.masksToBounds = true
        }

        // ImageViewのフレームは画像の実際のサイズに設定
        customImageView.frame = NSRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height)

        // 画像を表示エリアに適合させる拡大率を設定
        customImageView.setScale(initialScale)

        // 画像を中央に配置
        let scaledImageWidth = imageSize.width * initialScale
        let scaledImageHeight = imageSize.height * initialScale
        let centerX = (availableWidth - scaledImageWidth) / 2
        let centerY = (availableHeight - scaledImageHeight) / 2
        customImageView.setPanPosition(x: centerX, y: centerY)

        #if DEBUG
        print("🎯 Initial image layout:")
        print("  - Image size: \(imageSize)")
        print("  - Available area: \(availableWidth) x \(availableHeight)")
        print("  - Initial scale: \(initialScale)")
        print("  - Center position: (\(centerX), \(centerY))")
        #endif
    }

    func didEncounterError(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            // エラーログは重要なので、リリースビルドでも出力
            self?.logger.error("キャプチャエラー: \(error.localizedDescription)")
        }
    }

    func captureStateDidChange(_ isActive: Bool) {
        DispatchQueue.main.async { [weak self] in
            #if DEBUG
            if isActive {
                self?.logger.debug("📹 キャプチャが再開されました")
            } else {
                self?.logger.debug("⏸️ キャプチャが一時停止されました")
            }
            #endif
        }
    }
}
