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
        // マウスクリックを最初から受け入れる
        return !isClickThroughEnabled
    }

    func setClickThroughEnabled(_ enabled: Bool) {
        isClickThroughEnabled = enabled
        needsDisplay = true
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
    }

    private func setupStatusBarItem() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusBarItem?.button {
            button.image = NSImage(systemSymbolName: "video.circle", accessibilityDescription: "TransparentWindowCapture")
            button.toolTip = "TransparentWindowCapture"
        }

        setupStatusBarMenu()
    }

    private func setupStatusBarMenu() {
        let menu = NSMenu()

        // 全体クリック無視の切り替えメニューアイテム
        let clickThroughItem = NSMenuItem(title: "全体クリックを無視する", action: #selector(toggleClickThrough), keyEquivalent: "")
        clickThroughItem.target = self
        menu.addItem(clickThroughItem)

        // キャプチャエリアのみクリック無視の切り替えメニューアイテム
        let captureAreaOnlyItem = NSMenuItem(title: "キャプチャエリアのみクリックを無視する", action: #selector(toggleCaptureAreaOnly), keyEquivalent: "")
        captureAreaOnlyItem.target = self
        menu.addItem(captureAreaOnlyItem)

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

    @objc private func toggleClickThrough() {
        let isCurrentlyClickThrough = window.ignoresMouseEvents
        window.ignoresMouseEvents = !isCurrentlyClickThrough

        // メニューアイテムのタイトルを更新
        if let menu = statusBarItem?.menu,
           let clickThroughItem = menu.item(at: 0) {
            clickThroughItem.title = isCurrentlyClickThrough ? "全体クリックを無視する" : "全体クリックを有効にする"
            clickThroughItem.state = isCurrentlyClickThrough ? .off : .on
        }

        // ViewControllerに状態を通知
        viewController?.updateClickThroughState(!isCurrentlyClickThrough)
    }

    @objc private func toggleCaptureAreaOnly() {
        // ViewControllerのキャプチャエリアのみクリック無視を切り替え
        viewController?.toggleCaptureAreaOnlyMode()
    }

    @objc private func captureAreaOnlyModeChanged(_ notification: Notification) {
        guard let isEnabled = notification.object as? Bool else { return }

        // メニューアイテムのタイトルを更新
        if let menu = statusBarItem?.menu,
           let captureAreaOnlyItem = menu.item(at: 1) {
            captureAreaOnlyItem.title = isEnabled ? "キャプチャエリアのクリックを有効にする" : "キャプチャエリアのみクリックを無視する"
            captureAreaOnlyItem.state = isEnabled ? .on : .off
        }
    }

    @objc private func showMainWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupWindow() {
        let contentRect = NSRect(x: 0, y: 0, width: 800, height: 600)

        window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Transparent Window Capture"
        window.center()

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
class ViewController: NSViewController {
    // UI Components
    private var customImageView: ClickThroughImageView!
    private var windowListPopup: NSPopUpButton!
    private var startCaptureButton: NSButton!
    private var transparencySlider: NSSlider!
    private var clickThroughButton: NSButton!
    private var captureAreaOnlyButton: NSButton!
    private var statusLabel: NSTextField!

    // Properties
    private var windowCaptureManager: WindowCaptureManager?
    private var availableWindows: [SCWindow] = []
    private var isClickThroughEnabled = false
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

        // 初期透明度設定
        transparencySlider.doubleValue = 0.8
        updateWindowTransparency()
    }

    private func setupUI() {
        // Custom ImageView (click-through capable)
        customImageView = ClickThroughImageView(frame: NSRect(x: 20, y: 120, width: 760, height: 440))
        customImageView.imageScaling = .scaleProportionallyUpOrDown
        customImageView.wantsLayer = true
        customImageView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        view.addSubview(customImageView)

        // Window selection popup
        windowListPopup = NSPopUpButton(frame: NSRect(x: 20, y: 86, width: 300, height: 25))
        windowListPopup.addItem(withTitle: "ウィンドウを選択してください")
        view.addSubview(windowListPopup)

        // Start capture button
        startCaptureButton = NSButton(frame: NSRect(x: 330, y: 81, width: 100, height: 32))
        startCaptureButton.title = "キャプチャ開始"
        startCaptureButton.bezelStyle = .rounded
        startCaptureButton.target = self
        startCaptureButton.action = #selector(startCaptureButtonClicked(_:))
        view.addSubview(startCaptureButton)

        // Refresh button
        let refreshButton = NSButton(frame: NSRect(x: 442, y: 81, width: 80, height: 32))
        refreshButton.title = "更新"
        refreshButton.bezelStyle = .rounded
        refreshButton.target = self
        refreshButton.action = #selector(refreshWindowListClicked(_:))
        view.addSubview(refreshButton)

        // Transparency label and slider
        let transparencyLabel = NSTextField(frame: NSRect(x: 540, y: 90, width: 45, height: 16))
        transparencyLabel.stringValue = "透明度:"
        transparencyLabel.isEditable = false
        transparencyLabel.isBordered = false
        transparencyLabel.backgroundColor = NSColor.clear
        view.addSubview(transparencyLabel)

        transparencySlider = NSSlider(frame: NSRect(x: 590, y: 86, width: 190, height: 25))
        transparencySlider.minValue = 0.1
        transparencySlider.maxValue = 1.0
        transparencySlider.doubleValue = 0.8
        transparencySlider.target = self
        transparencySlider.action = #selector(transparencySliderChanged(_:))
        view.addSubview(transparencySlider)

        // Click-through buttons
        clickThroughButton = NSButton(frame: NSRect(x: 20, y: 50, width: 130, height: 32))
        clickThroughButton.title = "全体クリック無視"
        clickThroughButton.bezelStyle = .rounded
        clickThroughButton.target = self
        clickThroughButton.action = #selector(clickThroughButtonClicked(_:))
        view.addSubview(clickThroughButton)

        captureAreaOnlyButton = NSButton(frame: NSRect(x: 160, y: 50, width: 150, height: 32))
        captureAreaOnlyButton.title = "キャプチャ部のみ無視"
        captureAreaOnlyButton.bezelStyle = .rounded
        captureAreaOnlyButton.target = self
        captureAreaOnlyButton.action = #selector(captureAreaOnlyButtonClicked(_:))
        view.addSubview(captureAreaOnlyButton)

        // Status label
        statusLabel = NSTextField(frame: NSRect(x: 320, y: 56, width: 250, height: 20))
        statusLabel.isEditable = false
        statusLabel.isBordered = false
        statusLabel.backgroundColor = NSColor.clear
        statusLabel.font = NSFont.systemFont(ofSize: 12)
        view.addSubview(statusLabel)

        // Info label
        let infoLabel = NSTextField(frame: NSRect(x: 20, y: 20, width: 760, height: 16))
        infoLabel.stringValue = "※ このアプリにはスクリーン録画権限が必要です。システム設定 > プライバシーとセキュリティ > スクリーン録画 で許可してください。"
        infoLabel.isEditable = false
        infoLabel.isBordered = false
        infoLabel.backgroundColor = NSColor.clear
        infoLabel.textColor = NSColor.secondaryLabelColor
        infoLabel.font = NSFont.systemFont(ofSize: 11)
        view.addSubview(infoLabel)
    }

    // MARK: - Action Methods
    @objc private func clickThroughButtonClicked(_ sender: NSButton) {
        toggleClickThrough()
    }

    @objc private func captureAreaOnlyButtonClicked(_ sender: NSButton) {
        toggleCaptureAreaOnlyModeInternal()
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
            windowListPopup.isEnabled = true
        }
    }

    @objc private func refreshWindowListClicked(_ sender: NSButton) {
        loadAvailableWindows()
    }

    @objc private func transparencySliderChanged(_ sender: NSSlider) {
        updateWindowTransparency()
    }

    // MARK: - Click Through Methods
    private func toggleClickThrough() {
        isClickThroughEnabled.toggle()
        isCaptureAreaOnlyMode = false // 排他的モード

        view.window?.ignoresMouseEvents = isClickThroughEnabled
        customImageView?.setClickThroughEnabled(false)

        updateButtonTitles()
        updateStatusLabel()
    }

    private func toggleCaptureAreaOnlyModeInternal() {
        isCaptureAreaOnlyMode.toggle()
        isClickThroughEnabled = false // 排他的モード

        view.window?.ignoresMouseEvents = false
        customImageView?.setClickThroughEnabled(isCaptureAreaOnlyMode)

        updateButtonTitles()
        updateStatusLabel()
    }

    func updateClickThroughState(_ enabled: Bool) {
        isClickThroughEnabled = enabled
        isCaptureAreaOnlyMode = false
        customImageView?.setClickThroughEnabled(false)
        updateButtonTitles()
        updateStatusLabel()
    }

    func toggleCaptureAreaOnlyMode() {
        toggleCaptureAreaOnlyModeInternal()
    }

    private func updateButtonTitles() {
        clickThroughButton?.title = isClickThroughEnabled ? "全体クリック有効" : "全体クリック無視"
        captureAreaOnlyButton?.title = isCaptureAreaOnlyMode ? "キャプチャ部有効" : "キャプチャ部のみ無視"
    }

    private func updateStatusLabel() {
        var status = ""
        var color = NSColor.systemRed

        if isClickThroughEnabled {
            status = "クリック無視: 全体"
            color = .systemGreen
        } else if isCaptureAreaOnlyMode {
            status = "クリック無視: キャプチャ部のみ"
            color = .systemOrange
        } else {
            status = "クリック無視: 無効"
            color = .systemRed
        }

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
}

// MARK: - WindowCaptureManagerDelegate
@available(macOS 12.3, *)
extension ViewController: WindowCaptureManagerDelegate {
    func didReceiveNewFrame(_ image: NSImage) {
        DispatchQueue.main.async {
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