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

// MARK: - Control Panel Delegate Protocol
@available(macOS 12.3, *)
protocol ControlPanelDelegate: AnyObject {
    func controlPanelDidRefreshWindowList(_ panel: ControlPanelViewController)
    func controlPanel(_ panel: ControlPanelViewController, didChangeTransparency alpha: Double)
    func controlPanel(_ panel: ControlPanelViewController, didChangeFrameRate frameRate: Double)
    func controlPanel(_ panel: ControlPanelViewController, didToggleClickThrough enabled: Bool)
    func controlPanel(_ panel: ControlPanelViewController, didToggleAlwaysOnTop enabled: Bool)
    func controlPanel(_ panel: ControlPanelViewController, didStartCapture window: SCWindow, frameRate: Double)
    func controlPanelDidStopCapture(_ panel: ControlPanelViewController)

    // Transform controls
    func controlPanelDidZoomIn(_ panel: ControlPanelViewController)
    func controlPanelDidZoomOut(_ panel: ControlPanelViewController)
    func controlPanelDidResetTransform(_ panel: ControlPanelViewController)
}

// MARK: - Control Panel View Controller
@available(macOS 12.3, *)
class ControlPanelViewController: NSViewController {

    // MARK: - Delegate
    weak var delegate: ControlPanelDelegate?

    // MARK: - UI Components
    private var windowListPopup: NSPopUpButton!
    private var startCaptureButton: NSButton!
    private var refreshButton: NSButton!
    private var transparencySlider: NSSlider!
    private var frameRateSlider: NSSlider!
    private var frameRateTextField: NSTextField!
    private var clickThroughButton: NSButton!
    private var alwaysOnTopButton: NSButton!
    private var statusLabel: NSTextField!

    // Transform control UI components
    private var zoomInButton: NSButton!
    private var zoomOutButton: NSButton!
    private var resetTransformButton: NSButton!

    // MARK: - Properties
    private var availableWindows: [SCWindow] = []
    private var isClickThroughEnabled = false
    private var isAlwaysOnTopEnabled = false
    private var currentFrameRate: Double = 3.0
    private var isCapturing = false

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 160)) // 高さを120から160に変更
        setupUI()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // 初期不透明度設定（100%）
        transparencySlider.doubleValue = 1.0

        // 初期ボタンの状態を設定
        updateButtonTitles()
        updateStatusLabel()

        // ウィンドウリストを読み込み
        loadAvailableWindows()
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        // Window selection popup (1st row) - Y座標を上に調整
        windowListPopup = NSPopUpButton(frame: NSRect(x: 20, y: 120, width: 300, height: 25))
        windowListPopup.addItem(withTitle: "ウィンドウを選択してください")
        view.addSubview(windowListPopup)

        // Start capture button
        startCaptureButton = NSButton(frame: NSRect(x: 330, y: 115, width: 120, height: 32))
        startCaptureButton.title = "キャプチャ開始"
        startCaptureButton.bezelStyle = .rounded
        startCaptureButton.target = self
        startCaptureButton.action = #selector(startCaptureButtonClicked(_:))
        view.addSubview(startCaptureButton)

        // Refresh button
        refreshButton = NSButton(frame: NSRect(x: 460, y: 115, width: 100, height: 32))
        refreshButton.title = "リスト更新"
        refreshButton.bezelStyle = .rounded
        refreshButton.target = self
        refreshButton.action = #selector(refreshWindowListClicked(_:))
        view.addSubview(refreshButton)

        // Transparency label and slider (2nd row) - Y座標を上に調整
        let transparencyLabel = NSTextField(frame: NSRect(x: 20, y: 91, width: 70, height: 16))
        transparencyLabel.stringValue = "不透明度:"
        transparencyLabel.isEditable = false
        transparencyLabel.isBordered = false
        transparencyLabel.backgroundColor = NSColor.clear
        view.addSubview(transparencyLabel)

        transparencySlider = NSSlider(frame: NSRect(x: 95, y: 87, width: 300, height: 25))
        transparencySlider.minValue = 0.1
        transparencySlider.maxValue = 1.0
        transparencySlider.doubleValue = 1.0
        transparencySlider.target = self
        transparencySlider.action = #selector(transparencySliderChanged(_:))
        view.addSubview(transparencySlider)

        // Frame rate label and controls (2nd row) - Y座標を上に調整
        let frameRateLabel = NSTextField(frame: NSRect(x: 410, y: 91, width: 30, height: 16))
        frameRateLabel.stringValue = "fps:"
        frameRateLabel.isEditable = false
        frameRateLabel.isBordered = false
        frameRateLabel.backgroundColor = NSColor.clear
        view.addSubview(frameRateLabel)

        frameRateSlider = NSSlider(frame: NSRect(x: 445, y: 87, width: 180, height: 25))
        frameRateSlider.minValue = 1.0
        frameRateSlider.maxValue = 60.0
        frameRateSlider.doubleValue = currentFrameRate
        frameRateSlider.target = self
        frameRateSlider.action = #selector(frameRateSliderChanged(_:))
        view.addSubview(frameRateSlider)

        frameRateTextField = NSTextField(frame: NSRect(x: 635, y: 87, width: 50, height: 25))
        frameRateTextField.stringValue = String(format: "%.0f", currentFrameRate)
        frameRateTextField.isEditable = true
        frameRateTextField.target = self
        frameRateTextField.action = #selector(frameRateTextFieldChanged(_:))
        view.addSubview(frameRateTextField)

        // Click-through and Always On Top buttons (3rd row) - 少し上に調整
        clickThroughButton = NSButton(frame: NSRect(x: 20, y: 55, width: 130, height: 32))
        clickThroughButton.title = "クリック透過"
        clickThroughButton.bezelStyle = .rounded
        clickThroughButton.target = self
        clickThroughButton.action = #selector(clickThroughButtonClicked(_:))
        view.addSubview(clickThroughButton)

        alwaysOnTopButton = NSButton(frame: NSRect(x: 160, y: 55, width: 120, height: 32))
        alwaysOnTopButton.title = "常に手前表示"
        alwaysOnTopButton.bezelStyle = .rounded
        alwaysOnTopButton.target = self
        alwaysOnTopButton.action = #selector(alwaysOnTopButtonClicked(_:))
        view.addSubview(alwaysOnTopButton)

        // Status label (3rd row)
        statusLabel = NSTextField(frame: NSRect(x: 290, y: 61, width: 280, height: 20))
        statusLabel.isEditable = false
        statusLabel.isBordered = false
        statusLabel.backgroundColor = NSColor.clear
        statusLabel.font = NSFont.systemFont(ofSize: 12)
        view.addSubview(statusLabel)

        // Reset button
        let resetButton = NSButton(frame: NSRect(x: 580, y: 55, width: 100, height: 32))
        resetButton.title = "全てリセット"
        resetButton.bezelStyle = .rounded
        resetButton.target = self
        resetButton.action = #selector(resetAllClicked(_:))
        view.addSubview(resetButton)

        // Transform controls (最下行)
        zoomOutButton = NSButton(frame: NSRect(x: 20, y: 20, width: 60, height: 25))
        zoomOutButton.title = "🔍-"
        zoomOutButton.bezelStyle = .rounded
        zoomOutButton.target = self
        zoomOutButton.action = #selector(zoomOutClicked(_:))
        view.addSubview(zoomOutButton)

        zoomInButton = NSButton(frame: NSRect(x: 65, y: 20, width: 60, height: 25))
        zoomInButton.title = "🔍+"
        zoomInButton.bezelStyle = .rounded
        zoomInButton.target = self
        zoomInButton.action = #selector(zoomInClicked(_:))
        view.addSubview(zoomInButton)

        resetTransformButton = NSButton(frame: NSRect(x: 115, y: 20, width: 80, height: 25))
        resetTransformButton.title = "↺"
        resetTransformButton.bezelStyle = .rounded
        resetTransformButton.target = self
        resetTransformButton.action = #selector(resetTransformClicked(_:))
        view.addSubview(resetTransformButton)
    }

    // MARK: - Action Methods
    @objc private func startCaptureButtonClicked(_ sender: NSButton) {
        if !isCapturing {
            let selectedIndex = windowListPopup.indexOfSelectedItem
            guard selectedIndex >= 0 && selectedIndex < availableWindows.count else {
                return
            }

            let selectedWindow = availableWindows[selectedIndex]
            delegate?.controlPanel(self, didStartCapture: selectedWindow, frameRate: currentFrameRate)

            isCapturing = true
            sender.title = "キャプチャ停止"
            windowListPopup.isEnabled = false
        } else {
            delegate?.controlPanelDidStopCapture(self)

            isCapturing = false
            sender.title = "キャプチャ開始"
            windowListPopup.isEnabled = true
        }
    }

    @objc private func refreshWindowListClicked(_ sender: NSButton) {
        loadAvailableWindows()
        delegate?.controlPanelDidRefreshWindowList(self)
    }

    @objc private func transparencySliderChanged(_ sender: NSSlider) {
        delegate?.controlPanel(self, didChangeTransparency: sender.doubleValue)
    }

    @objc private func frameRateSliderChanged(_ sender: NSSlider) {
        currentFrameRate = sender.doubleValue
        frameRateTextField.stringValue = String(format: "%.0f", currentFrameRate)
        delegate?.controlPanel(self, didChangeFrameRate: currentFrameRate)
    }

    @objc private func frameRateTextFieldChanged(_ sender: NSTextField) {
        if let value = Double(sender.stringValue) {
            let clampedValue = max(1.0, min(60.0, value))
            currentFrameRate = clampedValue
            frameRateSlider.doubleValue = clampedValue
            frameRateTextField.stringValue = String(format: "%.0f", clampedValue)
            delegate?.controlPanel(self, didChangeFrameRate: currentFrameRate)
        } else {
            frameRateTextField.stringValue = String(format: "%.0f", currentFrameRate)
        }
    }

    @objc private func clickThroughButtonClicked(_ sender: NSButton) {
        isClickThroughEnabled.toggle()
        updateButtonTitles()
        updateStatusLabel()
        delegate?.controlPanel(self, didToggleClickThrough: isClickThroughEnabled)
    }

    @objc private func alwaysOnTopButtonClicked(_ sender: NSButton) {
        isAlwaysOnTopEnabled.toggle()
        updateButtonTitles()
        updateStatusLabel()

        // コントロールパネル自体の常に手前表示状態も更新
        if let window = view.window {
            window.level = isAlwaysOnTopEnabled ? .floating : .normal
        }

        delegate?.controlPanel(self, didToggleAlwaysOnTop: isAlwaysOnTopEnabled)
    }

    @objc private func resetAllClicked(_ sender: NSButton) {
        // 各設定を初期値にリセット
        transparencySlider.doubleValue = 1.0
        delegate?.controlPanel(self, didChangeTransparency: 1.0)

        isClickThroughEnabled = false
        isAlwaysOnTopEnabled = false

        // コントロールパネル自体の状態もリセット
        if let window = view.window {
            window.level = .normal
        }

        updateButtonTitles()
        updateStatusLabel()

        delegate?.controlPanel(self, didToggleClickThrough: false)
        delegate?.controlPanel(self, didToggleAlwaysOnTop: false)
    }

    // MARK: - Window List Management
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
                // エラーログは重要なので、リリースビルドでも出力
                os_log(.error, "ウィンドウ一覧の取得に失敗: %@", error.localizedDescription)
                DispatchQueue.main.async {
                    self.windowListPopup.addItem(withTitle: "ウィンドウ取得エラー")
                    self.startCaptureButton.isEnabled = false
                }
            }
        }
    }

    // MARK: - UI Update Methods
    private func updateButtonTitles() {
        clickThroughButton?.title = isClickThroughEnabled ? "✓ クリック透過" : "クリック透過"
        alwaysOnTopButton?.title = isAlwaysOnTopEnabled ? "✓ 常に手前表示" : "常に手前表示"
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

    // MARK: - Public Interface for External Updates
    func updateCaptureButtonState(isCapturing: Bool) {
        self.isCapturing = isCapturing
        startCaptureButton.title = isCapturing ? "キャプチャ停止" : "キャプチャ開始"
        windowListPopup.isEnabled = !isCapturing
    }

    func updateTransparencyValue(_ value: Double) {
        transparencySlider.doubleValue = value
    }

    func updateClickThroughState(_ enabled: Bool) {
        isClickThroughEnabled = enabled
        updateButtonTitles()
        updateStatusLabel()
    }

    func updateAlwaysOnTopState(_ enabled: Bool) {
        isAlwaysOnTopEnabled = enabled

        // コントロールパネル自体の状態も更新
        if let window = view.window {
            window.level = enabled ? .floating : .normal
        }

        updateButtonTitles()
        updateStatusLabel()
    }
}

// MARK: - Transform Action Methods
@available(macOS 12.3, *)
extension ControlPanelViewController {
    @objc private func zoomInClicked(_ sender: NSButton) {
        delegate?.controlPanelDidZoomIn(self)
    }

    @objc private func zoomOutClicked(_ sender: NSButton) {
        delegate?.controlPanelDidZoomOut(self)
    }

    @objc private func resetTransformClicked(_ sender: NSButton) {
        delegate?.controlPanelDidResetTransform(self)
    }
}
