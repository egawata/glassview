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
    private var windowListPopup: NSPopUpButton!
    private var startCaptureButton: NSButton!
    private var refreshButton: NSButton!
    private var transparencySlider: NSSlider!
    private var frameRateSlider: NSSlider!
    private var frameRateTextField: NSTextField!
    private var clickThroughButton: NSButton!
    private var alwaysOnTopButton: NSButton!
    private var statusLabel: NSTextField!

    // Tips display components
    private var tipsContainerView: NSView!
    private var tipsLabel: NSTextField!
    private var tipsImageView: NSImageView!

    // UI Control Registry for Observer Pattern
    private let uiControlRegistry = UIControlRegistry()

    // Properties
    private var windowCaptureManager: WindowCaptureManager?
    private var availableWindows: [SCWindow] = []
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
        loadAvailableWindows()
        updateStatusLabel()

        // 初期不透明度設定（100%）
        transparencySlider.doubleValue = 1.0
        updateWindowTransparency()

        // ウィンドウリサイズの監視を設定
        setupWindowResizeObserver()

        // 初期ボタンの状態を設定
        updateButtonTitles()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        // ビューのレイアウトが変更された時にキャプチャエリアのサイズも調整
        updateCaptureAreaLayout()
    }

    private func setupUI() {
        // Custom ImageView (click-through capable) - アスペクト比保持でリサイズ
        customImageView = ClickThroughImageView(frame: NSRect(x: 20, y: 120, width: 760, height: 420))
        customImageView.imageScaling = .scaleProportionallyUpOrDown // アスペクト比を保持してサイズ調整
        customImageView.imageAlignment = .alignCenter
        customImageView.wantsLayer = true
        customImageView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        view.addSubview(customImageView)

        // Setup Tips container
        setupTipsDisplay()

        // Window selection popup
        windowListPopup = NSPopUpButton(frame: NSRect(x: 20, y: 86, width: 300, height: 25))
        windowListPopup.addItem(withTitle: "ウィンドウを選択してください")
        view.addSubview(windowListPopup)

        // Start capture button
        startCaptureButton = NSButton(frame: NSRect(x: 330, y: 81, width: 120, height: 32))
        startCaptureButton.title = "キャプチャ開始"
        startCaptureButton.bezelStyle = .rounded
        startCaptureButton.target = self
        startCaptureButton.action = #selector(startCaptureButtonClicked(_:))
        view.addSubview(startCaptureButton)

        // Refresh button
        refreshButton = NSButton(frame: NSRect(x: 460, y: 81, width: 100, height: 32))
        refreshButton.title = "リスト更新"
        refreshButton.bezelStyle = .rounded
        refreshButton.target = self
        refreshButton.action = #selector(refreshWindowListClicked(_:))
        view.addSubview(refreshButton)

        // Transparency label and slider (2nd row)
        let transparencyLabel = NSTextField(frame: NSRect(x: 20, y: 61, width: 70, height: 16))
        transparencyLabel.stringValue = "不透明度:"
        transparencyLabel.isEditable = false
        transparencyLabel.isBordered = false
        transparencyLabel.backgroundColor = NSColor.clear
        view.addSubview(transparencyLabel)

        transparencySlider = NSSlider(frame: NSRect(x: 95, y: 57, width: 300, height: 25))
        transparencySlider.minValue = 0.1
        transparencySlider.maxValue = 1.0
        transparencySlider.doubleValue = 1.0
        transparencySlider.target = self
        transparencySlider.action = #selector(transparencySliderChanged(_:))
        view.addSubview(transparencySlider)

        // Frame rate label and controls (2nd row)
        let frameRateLabel = NSTextField(frame: NSRect(x: 410, y: 61, width: 30, height: 16))
        frameRateLabel.stringValue = "fps:"
        frameRateLabel.isEditable = false
        frameRateLabel.isBordered = false
        frameRateLabel.backgroundColor = NSColor.clear
        view.addSubview(frameRateLabel)

        frameRateSlider = NSSlider(frame: NSRect(x: 445, y: 57, width: 180, height: 25))
        frameRateSlider.minValue = 1.0
        frameRateSlider.maxValue = 60.0
        frameRateSlider.doubleValue = currentFrameRate
        frameRateSlider.target = self
        frameRateSlider.action = #selector(frameRateSliderChanged(_:))
        view.addSubview(frameRateSlider)

        frameRateTextField = NSTextField(frame: NSRect(x: 635, y: 57, width: 50, height: 25))
        frameRateTextField.stringValue = String(format: "%.0f", currentFrameRate)
        frameRateTextField.isEditable = true
        frameRateTextField.target = self
        frameRateTextField.action = #selector(frameRateTextFieldChanged(_:))
        view.addSubview(frameRateTextField)

        // Click-through buttons (3rd row)
        clickThroughButton = NSButton(frame: NSRect(x: 20, y: 31, width: 130, height: 32))
        clickThroughButton.title = "クリック透過"
        clickThroughButton.bezelStyle = .rounded
        clickThroughButton.target = self
        clickThroughButton.action = #selector(clickThroughButtonClicked(_:))
        view.addSubview(clickThroughButton)

        // Always on top button
        alwaysOnTopButton = NSButton(frame: NSRect(x: 160, y: 31, width: 120, height: 32))
        alwaysOnTopButton.title = "常に手前表示"
        alwaysOnTopButton.bezelStyle = .rounded
        alwaysOnTopButton.target = self
        alwaysOnTopButton.action = #selector(alwaysOnTopButtonClicked(_:))
        view.addSubview(alwaysOnTopButton)

        // Status label (3rd row)
        statusLabel = NSTextField(frame: NSRect(x: 290, y: 37, width: 480, height: 20))
        statusLabel.isEditable = false
        statusLabel.isBordered = false
        statusLabel.backgroundColor = NSColor.clear
        statusLabel.font = NSFont.systemFont(ofSize: 12)
        view.addSubview(statusLabel)

        // Info label
        let infoLabel = NSTextField(frame: NSRect(x: 20, y: 5, width: 760, height: 16))
        infoLabel.stringValue = "※ このアプリにはスクリーン録画権限が必要です。システム設定 > プライバシーとセキュリティ > スクリーン録画 で許可してください。"
        infoLabel.isEditable = false
        infoLabel.isBordered = false
        infoLabel.backgroundColor = NSColor.clear
        infoLabel.textColor = NSColor.secondaryLabelColor
        infoLabel.font = NSFont.systemFont(ofSize: 11)
        view.addSubview(infoLabel)

        registerUIControls()
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

    func resetAllToInitialState() {
        // 不透明度を初期値にリセット
        transparencySlider?.doubleValue = 1.0
        updateWindowTransparency()

        // クリック透過を無効化
        clickThroughButton?.title = "クリック透過: 無効"
        updateClickThroughState(false)

        // 常に手前表示を無効化
        alwaysOnTopButton?.title = "常に手前: 無効"
        updateAlwaysOnTopState(false)

        // フレームレートはリセット対象外（現在の値を維持）

        // キャプチャは継続したまま（停止しない）
    }

    // MARK: - UI Control Registration
    private func registerUIControls() {
        // Register all buttons and controls that should be managed by the registry
        uiControlRegistry.register(startCaptureButton)
        uiControlRegistry.register(refreshButton)
        uiControlRegistry.register(windowListPopup)
        uiControlRegistry.register(alwaysOnTopButton)
        uiControlRegistry.register(transparencySlider)
        uiControlRegistry.register(frameRateSlider)
        uiControlRegistry.register(frameRateTextField)
        uiControlRegistry.register(clickThroughButton)
    }

    // MARK: - Dynamic UI Control Management
    /// 新しいコントロールを追加して自動的にRegistryに登録する
    func addUIControl(_ control: NSControl, alwaysEnabled: Bool = false) {
        uiControlRegistry.register(control, alwaysEnabled: alwaysEnabled)
        view.addSubview(control)

        // 現在のクリック透過状態に応じてコントロールの状態を設定
        updateButtonStatesForClickThrough()
    }

    func removeUIControl(_ control: NSControl) {
        uiControlRegistry.unregister(control)
        control.removeFromSuperview()
    }

    // MARK: - Action Methods
    @objc private func clickThroughButtonClicked(_ sender: NSButton) {
        toggleClickThrough()
    }

    @objc private func alwaysOnTopButtonClicked(_ sender: NSButton) {
        toggleAlwaysOnTop()
    }

    @objc private func startCaptureButtonClicked(_ sender: NSButton) {
        let selectedIndex = windowListPopup.indexOfSelectedItem

        if sender.title == "キャプチャ開始" {
            guard selectedIndex >= 0 && selectedIndex < availableWindows.count else {
                return
            }

            let selectedWindow = availableWindows[selectedIndex]
            windowCaptureManager?.startCapture(for: selectedWindow, frameRate: currentFrameRate)

            sender.title = "キャプチャ停止"
            windowListPopup.isEnabled = false

            // Hide tips display when capture starts
            hideTipsDisplay()
        } else {
            windowCaptureManager?.stopCapture()
            sender.title = "キャプチャ開始"
            windowListPopup.isEnabled = !isClickThroughEnabled // 全体クリック透過状態を考慮
        }

        updateButtonStatesForClickThrough()
    }

    @objc private func refreshWindowListClicked(_ sender: NSButton) {
        loadAvailableWindows()
    }

    @objc private func transparencySliderChanged(_ sender: NSSlider) {
        updateWindowTransparency()
    }

    @objc private func frameRateSliderChanged(_ sender: NSSlider) {
        currentFrameRate = sender.doubleValue
        frameRateTextField.stringValue = String(format: "%.0f", currentFrameRate)

        // キャプチャ中の場合、新しいフレームレートで再開
        if startCaptureButton.title == "キャプチャ停止" {
            windowCaptureManager?.updateFrameRate(currentFrameRate)
        }
    }

    @objc private func frameRateTextFieldChanged(_ sender: NSTextField) {
        if let value = Double(sender.stringValue) {
            let clampedValue = max(1.0, min(60.0, value))
            currentFrameRate = clampedValue
            frameRateSlider.doubleValue = clampedValue
            frameRateTextField.stringValue = String(format: "%.0f", clampedValue)

            // キャプチャ中の場合、新しいフレームレートで再開
            if startCaptureButton.title == "キャプチャ停止" {
                windowCaptureManager?.updateFrameRate(currentFrameRate)
            }
        } else {
            // 無効な入力の場合、現在の値に戻す
            frameRateTextField.stringValue = String(format: "%.0f", currentFrameRate)
        }
    }

    // MARK: - Opacity Reset Methods
    func resetOpacity() {
        transparencySlider.doubleValue = 1.0
        updateWindowTransparency()
    }

    // MARK: - Always On Top Methods
    private func toggleAlwaysOnTop() {
        isAlwaysOnTopEnabled.toggle()

        view.window?.level = isAlwaysOnTopEnabled ? .floating : .normal

        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.updateAlwaysOnTopMenuState(isAlwaysOnTopEnabled)
        }

        updateButtonTitles()
        updateStatusLabel()
    }

    func updateAlwaysOnTopState(_ enabled: Bool) {
        isAlwaysOnTopEnabled = enabled
        updateButtonTitles()
        updateStatusLabel()
    }

    // MARK: - Click Through Methods
    private func toggleClickThrough() {
        isClickThroughEnabled.toggle()

        (view.window as? ClickThroughWindow)?.setGlobalClickThroughEnabled(isClickThroughEnabled)
        customImageView?.setClickThroughEnabled(false)

        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.updateClickThroughMenuState(isClickThroughEnabled)
        }

        updateButtonTitles()
        updateStatusLabel()
    }

    func updateClickThroughState(_ enabled: Bool) {
        isClickThroughEnabled = enabled
        customImageView?.setClickThroughEnabled(false)
        updateButtonTitles()
        updateStatusLabel()
    }

    private func updateButtonTitles() {
        clickThroughButton?.title = isClickThroughEnabled ? "✓ クリック透過" : "クリック透過"
        alwaysOnTopButton?.title = isAlwaysOnTopEnabled ? "✓ 常に手前表示" : "常に手前表示"

        // クリック透過が有効な場合、ボタン類を無効化
        updateButtonStatesForClickThrough()
    }

    private func updateButtonStatesForClickThrough() {
        if isClickThroughEnabled {
            // クリック透過が有効な場合、すべてのコントロールを無効化
            uiControlRegistry.setAllControlsEnabled(false)
        } else {
            // クリック透過が無効な場合、すべてのコントロールを有効化
            uiControlRegistry.setAllControlsEnabled(true)

            // ただし、キャプチャ中はウィンドウ選択ポップアップを無効にする
            if startCaptureButton?.title != "キャプチャ開始" {
                windowListPopup?.isEnabled = false
                windowListPopup?.alphaValue = 0.5
            }
        }
    }

    private func updateStatusLabel() {
        var statusParts: [String] = []
        var color = NSColor.systemRed

        // Always On Top状態
        if isAlwaysOnTopEnabled {
            statusParts.append("常に手前表示")
            color = .systemBlue
        }

        // Click Through状態
        if isClickThroughEnabled {
            statusParts.append("クリック透過: 有効")
            color = .systemGreen
        } else {
            statusParts.append("クリック透過: 無効")
            if !isAlwaysOnTopEnabled {
                color = .systemRed
            }
        }

        let status = statusParts.joined(separator: " | ")
        statusLabel?.stringValue = status
        statusLabel?.textColor = color
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

    private func loadAvailableWindows() {
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)

                DispatchQueue.main.async {
                    self.windowListPopup.removeAllItems()
                    self.availableWindows = []

                    // filter：実際のアプリケーションウィンドウのみ
                    let filteredWindows = content.windows.filter { window in
                        return window.title?.isEmpty == false &&
                               window.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier &&
                               window.frame.width > 50 && window.frame.height > 50
                    }

                    if filteredWindows.isEmpty {
                        self.windowListPopup.addItem(withTitle: "利用可能なウィンドウがありません")
                        self.startCaptureButton.isEnabled = false
                    } else {
                        for window in filteredWindows {
                            let windowTitle = window.title ?? "無題のウィンドウ"
                            let appName = window.owningApplication?.applicationName ?? "不明なアプリ"

                            let displayTitle = "\(appName) - \(windowTitle)"

                            self.windowListPopup.addItem(withTitle: displayTitle)
                            self.availableWindows.append(window)
                        }

                        self.startCaptureButton.isEnabled = true
                    }
                }
            } catch {
                print("ウィンドウ一覧の取得に失敗: \(error)")
                DispatchQueue.main.async {
                    self.windowListPopup.addItem(withTitle: "ウィンドウ取得エラー")
                    self.startCaptureButton.isEnabled = false
                }
            }
        }
    }

    private func updateWindowTransparency() {
        let alphaValue = transparencySlider.doubleValue
        view.window?.alphaValue = CGFloat(alphaValue)
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
        let bottomControlsHeight: CGFloat = 120 // コントロール部分の高さ（3段レイアウト対応）

        // キャプチャエリアの新しいフレームを計算
        let newFrame = NSRect(
            x: margin,
            y: bottomControlsHeight + margin,
            width: windowFrame.width - (margin * 2),
            height: windowFrame.height - bottomControlsHeight - (margin * 2)
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
            self.startCaptureButton.title = "キャプチャ開始"
        }
    }
}
