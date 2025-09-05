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

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        setupUI()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupWindowTransparency()
        setupWindowCaptureManager()

        // ウィンドウリサイズの監視を設定
        setupWindowResizeObserver()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        // ビューのレイアウトが変更された時にキャプチャエリアのサイズも調整
        updateCaptureAreaLayout()
    }

    private func setupUI() {
        // Custom ImageView (click-through capable) - アスペクト比保持でリサイズ
        customImageView = ClickThroughImageView(frame: NSRect(x: 20, y: 20, width: 760, height: 560))
        customImageView.imageScaling = .scaleProportionallyUpOrDown // アスペクト比を保持してサイズ調整
        customImageView.imageAlignment = .alignCenter
        customImageView.wantsLayer = true
        customImageView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        view.addSubview(customImageView)

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
        tipsLabel.stringValue = "Tips:\n画面操作に困ったらデスクトップ上部メニューバーの\n「全てリセット」を選択してください"
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
        tipsContainerView.addSubview(tipsImageView)

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

        let windowFrame = window.contentView?.frame ?? NSRect.zero
        let margin: CGFloat = 20

        // キャプチャエリアの新しいフレームを計算
        let newFrame = NSRect(
            x: margin,
            y: margin,
            width: windowFrame.width - (margin * 2),
            height: windowFrame.height - (margin * 2)
        )

        // フレームを更新
        customImageView.frame = newFrame

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
}

// MARK: - WindowCaptureManagerDelegate
@available(macOS 12.3, *)
extension ViewController: WindowCaptureManagerDelegate {
    func didReceiveNewFrame(_ image: NSImage) {
        DispatchQueue.main.async {
            // 画像をキャプチャエリアに設定
            // NSImageViewのimageScalingが.scaleProportionallyUpOrDownに設定されているため、
            // アスペクト比を保持しながら自動的にフィットされる
            self.customImageView.image = image
        }
    }

    func didEncounterError(_ error: Error) {
        DispatchQueue.main.async {
            print("キャプチャエラー: \(error)")
        }
    }
}
