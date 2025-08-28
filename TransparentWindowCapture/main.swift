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
import CoreGraphics
import CoreImage

// MARK: - Custom Image View for Click-Through
@available(macOS 12.3, *)
class ClickThroughImageView: NSImageView {
    var isClickThroughEnabled = false

    override func hitTest(_ point: NSPoint) -> NSView? {
        if isClickThroughEnabled {
            // クリック透過が有効な場合は、このビューではヒットテストを行わない
            return nil
        }
        return super.hitTest(point)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        // クリック透過が有効な場合は、マウスクリックを受け入れない
        return !isClickThroughEnabled
    }

    override func mouseDown(with event: NSEvent) {
        if !isClickThroughEnabled {
            super.mouseDown(with: event)
        }
        // クリック透過が有効な場合は何もしない
    }

    override func mouseUp(with event: NSEvent) {
        if !isClickThroughEnabled {
            super.mouseUp(with: event)
        }
        // クリック透過が有効な場合は何もしない
    }

    override func mouseDragged(with event: NSEvent) {
        if !isClickThroughEnabled {
            super.mouseDragged(with: event)
        }
        // クリック透過が有効な場合は何もしない
    }

    func setClickThroughEnabled(_ enabled: Bool) {
        isClickThroughEnabled = enabled
        needsDisplay = true
    }
}

// MARK: - Custom Window for Click-Through
@available(macOS 12.3, *)
class ClickThroughWindow: NSWindow {
    var isGlobalClickThroughEnabled = false

    override var canBecomeKey: Bool {
        // 全体クリック無視が有効な場合は、キーウィンドウにならない
        return !isGlobalClickThroughEnabled
    }

    override var canBecomeMain: Bool {
        // 全体クリック無視が有効な場合は、メインウィンドウにならない
        return !isGlobalClickThroughEnabled
    }

    override func sendEvent(_ event: NSEvent) {
        if isGlobalClickThroughEnabled {
            // 全体クリック無視が有効な場合は、イベントを処理しない
            // ただし、右クリックメニューは許可する
            if event.type == .rightMouseDown || event.type == .rightMouseUp {
                super.sendEvent(event)
            }
            return
        }
        super.sendEvent(event)
    }

    func setGlobalClickThroughEnabled(_ enabled: Bool) {
        isGlobalClickThroughEnabled = enabled
        ignoresMouseEvents = enabled

        if enabled {
            // クリック無視を有効にする場合は、フォーカスも失わせる
            resignKey()
            resignMain()
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let captureAreaOnlyModeChanged = Notification.Name("captureAreaOnlyModeChanged")
}

// MARK: - App Delegate
@available(macOS 12.3, *)
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    private var statusBarItem: NSStatusItem?
    private var viewController: ViewController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBarItem()
        setupWindow()

        // 通知を監視
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(captureAreaOnlyModeChanged(_:)),
            name: .captureAreaOnlyModeChanged,
            object: nil
        )

        // 初期状態でメニューバーの状態を同期
        updateAllMenuStates()
    }

    // 全てのメニュー状態を現在の設定と同期
    private func updateAllMenuStates() {
        let isAlwaysOnTop = window.level == .floating
        let isClickThrough = (window as? ClickThroughWindow)?.isGlobalClickThroughEnabled ?? false

        updateAlwaysOnTopMenuState(isAlwaysOnTop)
        updateClickThroughMenuState(isClickThrough)
    }

    private func setupStatusBarItem() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusBarItem?.button {
            button.image = NSImage(systemSymbolName: "video.circle", accessibilityDescription: "GlassView")
            button.toolTip = "GlassView"
        }

        setupStatusBarMenu()
    }

    private func setupStatusBarMenu() {
        let menu = NSMenu()

        // 常に手前表示の切り替えメニューアイテム
        let alwaysOnTopItem = NSMenuItem(title: "常に手前に表示", action: #selector(toggleAlwaysOnTop), keyEquivalent: "")
        alwaysOnTopItem.target = self
        menu.addItem(alwaysOnTopItem)

        menu.addItem(NSMenuItem.separator())

        // 全体クリック透過の切り替えメニューアイテム
        let clickThroughItem = NSMenuItem(title: "全体クリック透過", action: #selector(toggleClickThrough), keyEquivalent: "")
        clickThroughItem.target = self
        menu.addItem(clickThroughItem)

        // キャプチャエリアのみクリック透過の切り替えメニューアイテム
        let captureAreaOnlyItem = NSMenuItem(title: "キャプチャエリアのみクリック透過", action: #selector(toggleCaptureAreaOnly), keyEquivalent: "")
        captureAreaOnlyItem.target = self
        menu.addItem(captureAreaOnlyItem)

        menu.addItem(NSMenuItem.separator())

        // 不透明度をリセットメニューアイテム
        let resetOpacityItem = NSMenuItem(title: "不透明度をリセット", action: #selector(resetOpacity), keyEquivalent: "")
        resetOpacityItem.target = self
        menu.addItem(resetOpacityItem)

        menu.addItem(NSMenuItem.separator())

        // ウィンドウを表示メニューアイテム
        let showWindowItem = NSMenuItem(title: "ウィンドウを表示", action: #selector(showMainWindow), keyEquivalent: "")
        showWindowItem.target = self
        menu.addItem(showWindowItem)

        menu.addItem(NSMenuItem.separator())

        // 終了メニューアイテム
        let quitItem = NSMenuItem(title: "終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusBarItem?.menu = menu
    }

    @objc private func toggleAlwaysOnTop() {
        let currentLevel = window.level
        let isCurrentlyOnTop = currentLevel == .floating

        // ウィンドウレベルを切り替え
        window.level = isCurrentlyOnTop ? .normal : .floating

        // メニューアイテムの状態を更新
        updateAlwaysOnTopMenuState(!isCurrentlyOnTop)

        // ViewControllerに状態を通知
        viewController?.updateAlwaysOnTopState(!isCurrentlyOnTop)
    }

    // メニューバーの常に手前表示の状態を更新するメソッド
    func updateAlwaysOnTopMenuState(_ isEnabled: Bool) {
        if let menu = statusBarItem?.menu,
           let alwaysOnTopItem = menu.item(at: 0) {
            alwaysOnTopItem.title = "常に手前に表示"
            alwaysOnTopItem.state = isEnabled ? .on : .off
        }
    }

    @objc private func toggleClickThrough() {
        let isCurrentlyClickThrough = (window as? ClickThroughWindow)?.isGlobalClickThroughEnabled ?? false

        // カスタムウィンドウのクリック透過設定を使用
        (window as? ClickThroughWindow)?.setGlobalClickThroughEnabled(!isCurrentlyClickThrough)

        // メニューアイテムのタイトルを更新
        updateClickThroughMenuState(!isCurrentlyClickThrough)

        // ViewControllerに状態を通知
        viewController?.updateClickThroughState(!isCurrentlyClickThrough)

        // 全体クリック透過が有効になった場合、キャプチャエリアのみモードは無効にする
        if !isCurrentlyClickThrough {
            NotificationCenter.default.post(name: .captureAreaOnlyModeChanged, object: false)
        }
    }

    // メニューバーの全体クリック透過の状態を更新するメソッド
    func updateClickThroughMenuState(_ isEnabled: Bool) {
        if let menu = statusBarItem?.menu,
           let clickThroughItem = menu.item(at: 2) {
            clickThroughItem.title = "全体クリック透過"
            clickThroughItem.state = isEnabled ? .on : .off
        }
    }

    @objc private func toggleCaptureAreaOnly() {
        // ViewControllerのキャプチャエリアのみクリック無視を切り替え
        viewController?.toggleCaptureAreaOnlyMode()
    }

    @objc private func captureAreaOnlyModeChanged(_ notification: Notification) {
        guard let isEnabled = notification.object as? Bool else { return }

        // メニューアイテムのタイトルを更新
        if let menu = statusBarItem?.menu,
           let captureAreaOnlyItem = menu.item(at: 3) {
            captureAreaOnlyItem.title = "キャプチャエリアのみクリック透過"
            captureAreaOnlyItem.state = isEnabled ? .on : .off
        }
    }

    @objc private func showMainWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func resetOpacity() {
        // ViewControllerの不透明度をリセット
        viewController?.resetOpacity()
    }

    private func setupWindow() {
        let contentRect = NSRect(x: 0, y: 0, width: 800, height: 600)

        // カスタムウィンドウクラスを使用
        window = ClickThroughWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "GlassView"
        window.center()

        // 最小ウィンドウサイズを設定（UI要素が正常に表示できる最小サイズ）
        window.minSize = NSSize(width: 400, height: 300)

        let viewController = ViewController()
        window.contentViewController = viewController
        self.viewController = viewController // ViewControllerへの参照を保存

        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// MARK: - ViewController
@available(macOS 12.3, *)
// MARK: - UI Control Registry for Observer Pattern
@available(macOS 12.3, *)
class UIControlRegistry {
    private var registeredControls: [NSControl] = []
    private var alwaysEnabledControls: Set<NSControl> = []

    func register(_ control: NSControl, alwaysEnabled: Bool = false) {
        if !registeredControls.contains(control) {
            registeredControls.append(control)
            if alwaysEnabled {
                alwaysEnabledControls.insert(control)
            }
        }
    }

    func unregister(_ control: NSControl) {
        registeredControls.removeAll { $0 == control }
        alwaysEnabledControls.remove(control)
    }

    func setAllControlsEnabled(_ enabled: Bool, except excludedControls: [NSControl] = []) {
        for control in registeredControls {
            // alwaysEnabled が設定されているコントロールは除外条件に関係なく常に有効
            if alwaysEnabledControls.contains(control) {
                control.isEnabled = true
                control.alphaValue = 1.0
            } else if !excludedControls.contains(control) {
                control.isEnabled = enabled
                control.alphaValue = enabled ? 1.0 : 0.5
            }
        }
    }

    func getAllRegisteredControls() -> [NSControl] {
        return registeredControls
    }
}

@available(macOS 12.3, *)
class ViewController: NSViewController {
    // UI Components
    private var customImageView: ClickThroughImageView!
    private var windowListPopup: NSPopUpButton!
    private var startCaptureButton: NSButton!
    private var refreshButton: NSButton!
    private var transparencySlider: NSSlider!
    private var clickThroughButton: NSButton!
    private var captureAreaOnlyButton: NSButton!
    private var alwaysOnTopButton: NSButton!
    private var statusLabel: NSTextField!

    // UI Control Registry for Observer Pattern
    private let uiControlRegistry = UIControlRegistry()

    // Properties
    private var windowCaptureManager: WindowCaptureManager?
    private var availableWindows: [SCWindow] = []
    private var isClickThroughEnabled = false
    private var isAlwaysOnTopEnabled = false
    private var isCaptureAreaOnlyMode = false {
        didSet {
            // AppDelegateがアクセスできるように通知を送信
            NotificationCenter.default.post(name: .captureAreaOnlyModeChanged, object: isCaptureAreaOnlyMode)
        }
    }

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
        customImageView.imageAlignment = .alignCenter // 中央配置
        customImageView.wantsLayer = true
        customImageView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        view.addSubview(customImageView)

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

        transparencySlider = NSSlider(frame: NSRect(x: 95, y: 57, width: 685, height: 25))
        transparencySlider.minValue = 0.1
        transparencySlider.maxValue = 1.0
        transparencySlider.doubleValue = 1.0
        transparencySlider.target = self
        transparencySlider.action = #selector(transparencySliderChanged(_:))
        view.addSubview(transparencySlider)

        // Click-through buttons (3rd row)
        clickThroughButton = NSButton(frame: NSRect(x: 20, y: 31, width: 130, height: 32))
        clickThroughButton.title = "全体クリック透過"
        clickThroughButton.bezelStyle = .rounded
        clickThroughButton.target = self
        clickThroughButton.action = #selector(clickThroughButtonClicked(_:))
        view.addSubview(clickThroughButton)

        captureAreaOnlyButton = NSButton(frame: NSRect(x: 160, y: 31, width: 150, height: 32))
        captureAreaOnlyButton.title = "キャプチャ部のみ透過"
        captureAreaOnlyButton.bezelStyle = .rounded
        captureAreaOnlyButton.target = self
        captureAreaOnlyButton.action = #selector(captureAreaOnlyButtonClicked(_:))
        view.addSubview(captureAreaOnlyButton)

        // Always on top button
        alwaysOnTopButton = NSButton(frame: NSRect(x: 320, y: 31, width: 120, height: 32))
        alwaysOnTopButton.title = "常に手前表示"
        alwaysOnTopButton.bezelStyle = .rounded
        alwaysOnTopButton.target = self
        alwaysOnTopButton.action = #selector(alwaysOnTopButtonClicked(_:))
        view.addSubview(alwaysOnTopButton)

        // Status label (3rd row)
        statusLabel = NSTextField(frame: NSRect(x: 450, y: 37, width: 320, height: 20))
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

        // Register all UI controls to the registry for observer pattern
        registerUIControls()
    }

    // MARK: - UI Control Registration
    private func registerUIControls() {
        // Register all buttons and controls that should be managed by the registry
        uiControlRegistry.register(startCaptureButton)
        uiControlRegistry.register(refreshButton)
        uiControlRegistry.register(windowListPopup)
        uiControlRegistry.register(captureAreaOnlyButton)
        uiControlRegistry.register(alwaysOnTopButton)
        uiControlRegistry.register(transparencySlider)
        uiControlRegistry.register(clickThroughButton)  // クリック透過ボタンも登録
    }

    // MARK: - Dynamic UI Control Management
    /// 新しいコントロールを追加して自動的にRegistryに登録する
    func addUIControl(_ control: NSControl, alwaysEnabled: Bool = false) {
        uiControlRegistry.register(control, alwaysEnabled: alwaysEnabled)
        view.addSubview(control)

        // 現在のクリック透過状態に応じてコントロールの状態を設定
        updateButtonStatesForClickThrough()
    }

    /// コントロールを削除してRegistryからも登録解除する
    func removeUIControl(_ control: NSControl) {
        uiControlRegistry.unregister(control)
        control.removeFromSuperview()
    }

    // MARK: - Action Methods
    @objc private func clickThroughButtonClicked(_ sender: NSButton) {
        toggleClickThrough()
    }

    @objc private func captureAreaOnlyButtonClicked(_ sender: NSButton) {
        toggleCaptureAreaOnlyModeInternal()
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
            windowCaptureManager?.startCapture(for: selectedWindow)

            sender.title = "キャプチャ停止"
            windowListPopup.isEnabled = false
        } else {
            windowCaptureManager?.stopCapture()
            sender.title = "キャプチャ開始"
            windowListPopup.isEnabled = !isClickThroughEnabled // 全体クリック透過状態を考慮
        }

        // ボタンの状態を更新
        updateButtonStatesForClickThrough()
    }

    @objc private func refreshWindowListClicked(_ sender: NSButton) {
        loadAvailableWindows()
    }

    @objc private func transparencySliderChanged(_ sender: NSSlider) {
        updateWindowTransparency()
    }

    // MARK: - Opacity Reset Methods
    func resetOpacity() {
        // 不透明度を100%（1.0）にリセット
        transparencySlider.doubleValue = 1.0
        updateWindowTransparency()
    }

    // MARK: - Always On Top Methods
    private func toggleAlwaysOnTop() {
        isAlwaysOnTopEnabled.toggle()

        // ウィンドウレベルを更新（キャプチャエリアのみモードも考慮）
        if isCaptureAreaOnlyMode {
            // キャプチャエリアのみモードの場合は、専用レベルを維持
            view.window?.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue - 1)
        } else {
            // 通常モードの場合は、常に手前表示の状態に応じて設定
            view.window?.level = isAlwaysOnTopEnabled ? .floating : .normal
        }

        // AppDelegateのメニュー状態も更新
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
        isCaptureAreaOnlyMode = false // 排他的モード

        // カスタムウィンドウのクリック透過設定を使用
        (view.window as? ClickThroughWindow)?.setGlobalClickThroughEnabled(isClickThroughEnabled)
        customImageView?.setClickThroughEnabled(false)

        // AppDelegateのメニュー状態も更新
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.updateClickThroughMenuState(isClickThroughEnabled)
            // キャプチャエリアのみモードも無効になったことを通知
            if !isCaptureAreaOnlyMode {
                NotificationCenter.default.post(name: .captureAreaOnlyModeChanged, object: false)
            }
        }

        updateButtonTitles()
        updateStatusLabel()
    }

    private func toggleCaptureAreaOnlyModeInternal() {
        isCaptureAreaOnlyMode.toggle()
        isClickThroughEnabled = false // 排他的モード

        // 全体のクリック透過は無効にし、キャプチャエリアのみ設定
        (view.window as? ClickThroughWindow)?.setGlobalClickThroughEnabled(false)
        customImageView?.setClickThroughEnabled(isCaptureAreaOnlyMode)

        if isCaptureAreaOnlyMode {
            // キャプチャエリアのみクリック透過の場合、ウィンドウレベルを少し上げる
            // これにより、他のアプリケーションのクリックがより確実に背後に透過される
            view.window?.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue - 1)
        } else {
            // 通常状態または常に手前表示の状態に戻す
            view.window?.level = isAlwaysOnTopEnabled ? .floating : .normal
        }

        // メニューバーのチェック状態も更新（通知を通じて）
        // isCaptureAreaOnlyModeのdidSetで通知が送信される

        updateButtonTitles()
        updateStatusLabel()
    }

    func updateClickThroughState(_ enabled: Bool) {
        isClickThroughEnabled = enabled
        if enabled {
            isCaptureAreaOnlyMode = false // 排他的モード
        }
        customImageView?.setClickThroughEnabled(false)
        updateButtonTitles()
        updateStatusLabel()
    }

    func toggleCaptureAreaOnlyMode() {
        toggleCaptureAreaOnlyModeInternal()
    }

    private func updateButtonTitles() {
        clickThroughButton?.title = isClickThroughEnabled ? "✓ 全体クリック透過" : "全体クリック透過"
        captureAreaOnlyButton?.title = isCaptureAreaOnlyMode ? "✓ キャプチャ部のみ透過" : "キャプチャ部のみ透過"
        alwaysOnTopButton?.title = isAlwaysOnTopEnabled ? "✓ 常に手前表示" : "常に手前表示"

        // 全体クリック透過が有効な場合、他のボタンを無効化してUIの分かりやすさを向上
        updateButtonStatesForClickThrough()
    }

    private func updateButtonStatesForClickThrough() {
        if isClickThroughEnabled {
            // 全体クリック透過が有効な場合、すべてのコントロールを無効化
            // クリック透過ボタン自体も無効にする（どうせ押せないため）
            uiControlRegistry.setAllControlsEnabled(false)
        } else {
            // 全体クリック透過が無効な場合、すべてのコントロールを有効化
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
            statusParts.append("クリック透過: 全体")
            color = .systemGreen
        } else if isCaptureAreaOnlyMode {
            statusParts.append("クリック透過: キャプチャ部のみ")
            color = .systemOrange
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
        // ウィンドウの透明度を有効にする
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
                    // リストをクリア
                    self.windowListPopup.removeAllItems()
                    self.availableWindows = []

                    // フィルタリング：実際のアプリケーションウィンドウのみ
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

        // 現在の画像がある場合は再描画をトリガー
        if let currentImage = customImageView.image {
            customImageView.image = currentImage
            customImageView.needsDisplay = true
        }
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

// MARK: - WindowCaptureManager Protocol
protocol WindowCaptureManagerDelegate: AnyObject {
    func didReceiveNewFrame(_ image: NSImage)
    func didEncounterError(_ error: Error)
}

// MARK: - WindowCaptureManager
@available(macOS 12.3, *)
class WindowCaptureManager: NSObject, @unchecked Sendable {
    weak var delegate: WindowCaptureManagerDelegate?

    private var captureTimer: Timer?
    private var selectedWindow: SCWindow?

    func startCapture(for window: SCWindow) {
        selectedWindow = window

        // タイマーでキャプチャを開始（フレームレート制限）
        captureTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { _ in
            self.captureFrame()
        }
    }

    func stopCapture() {
        captureTimer?.invalidate()
        captureTimer = nil
        selectedWindow = nil
    }

    private func captureFrame() {
        guard let window = selectedWindow else { return }

        // macOS 14.0未満の場合の代替実装
        if #available(macOS 14.0, *) {
            Task {
                do {
                    let filter = SCContentFilter(desktopIndependentWindow: window)
                    let config = SCStreamConfiguration()
                    config.width = Int(window.frame.width)
                    config.height = Int(window.frame.height)
                    config.scalesToFit = true
                    config.showsCursor = false
                    config.backgroundColor = .clear

                    let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

                    DispatchQueue.main.async { [weak self] in
                        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
                        self?.delegate?.didReceiveNewFrame(nsImage)
                    }
                } catch {
                    DispatchQueue.main.async { [weak self] in
                        self?.delegate?.didEncounterError(error)
                    }
                }
            }
        } else {
            // macOS 14.0未満の場合はCGWindowListCreateImageを使用
            let windowID = CGWindowID(window.windowID)
            let imageOption: CGWindowImageOption = [.boundsIgnoreFraming, .shouldBeOpaque]

            guard let cgImage = CGWindowListCreateImage(
                CGRect.null,
                .optionIncludingWindow,
                windowID,
                imageOption
            ) else {
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.didEncounterError(NSError(domain: "WindowCapture", code: -1, userInfo: [NSLocalizedDescriptionKey: "ウィンドウキャプチャに失敗しました"]))
                }
                return
            }

            DispatchQueue.main.async { [weak self] in
                let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                self?.delegate?.didReceiveNewFrame(nsImage)
            }
        }
    }
}

// MARK: - Main Entry Point
@available(macOS 12.3, *)
func main() {
    // NSApplicationを初期化
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate

    // アプリケーションを実行
    app.run()
}

// メイン関数を実行
if #available(macOS 12.3, *) {
    main()
} else {
    fatalError("This application requires macOS 12.3 or later.")
}