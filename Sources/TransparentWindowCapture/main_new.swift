import AppKit
import ScreenCaptureKit
import CoreGraphics
import CoreImage

@available(macOS 12.3, *)
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupWindow()
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
        window.contentViewController = ViewController()
        window.makeKeyAndOrderFront(nil)
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func applicationShouldTerminateWhenLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

@available(macOS 12.3, *)
class ViewController: NSViewController {
    var captureImageView: NSImageView!
    var windowListPopup: NSPopUpButton!
    var startCaptureButton: NSButton!
    var transparencySlider: NSSlider!
    
    private var windowCaptureManager: WindowCaptureManager?
    private var availableWindows: [SCWindow] = []
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        setupUI()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupWindowTransparency()
        setupWindowCaptureManager()
        loadAvailableWindows()
        
        // 初期透明度設定
        transparencySlider.doubleValue = 0.8
        updateWindowTransparency()
    }
    
    private func setupUI() {
        // ImageView
        captureImageView = NSImageView(frame: NSRect(x: 20, y: 80, width: 760, height: 500))
        captureImageView.imageScaling = .scaleProportionallyUpOrDown
        captureImageView.wantsLayer = true
        captureImageView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        view.addSubview(captureImageView)
        
        // Window selection popup
        windowListPopup = NSPopUpButton(frame: NSRect(x: 20, y: 46, width: 300, height: 25))
        windowListPopup.addItem(withTitle: "ウィンドウを選択してください")
        view.addSubview(windowListPopup)
        
        // Start capture button
        startCaptureButton = NSButton(frame: NSRect(x: 330, y: 41, width: 100, height: 32))
        startCaptureButton.title = "キャプチャ開始"
        startCaptureButton.bezelStyle = .rounded
        startCaptureButton.target = self
        startCaptureButton.action = #selector(startCaptureButtonClicked(_:))
        view.addSubview(startCaptureButton)
        
        // Transparency slider
        let transparencyLabel = NSTextField(labelWithString: "透明度:")
        transparencyLabel.frame = NSRect(x: 450, y: 50, width: 60, height: 16)
        view.addSubview(transparencyLabel)
        
        transparencySlider = NSSlider(frame: NSRect(x: 520, y: 45, width: 150, height: 25))
        transparencySlider.minValue = 0.1
        transparencySlider.maxValue = 1.0
        transparencySlider.target = self
        transparencySlider.action = #selector(transparencySliderChanged(_:))
        view.addSubview(transparencySlider)
        
        // Refresh button
        let refreshButton = NSButton(frame: NSRect(x: 690, y: 41, width: 80, height: 32))
        refreshButton.title = "更新"
        refreshButton.bezelStyle = .rounded
        refreshButton.target = self
        refreshButton.action = #selector(refreshButtonClicked(_:))
        view.addSubview(refreshButton)
        
        // Status label
        let statusLabel = NSTextField(labelWithString: "透明なウィンドウでリアルタイムキャプチャ")
        statusLabel.frame = NSRect(x: 20, y: 15, width: 400, height: 20)
        statusLabel.font = NSFont.systemFont(ofSize: 12)
        statusLabel.textColor = NSColor.secondaryLabelColor
        view.addSubview(statusLabel)
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
                        guard let app = window.owningApplication else { return false }
                        guard !app.applicationName.isEmpty else { return false }
                        guard window.frame.width > 50 && window.frame.height > 50 else { return false }
                        return true
                    }
                    
                    if filteredWindows.isEmpty {
                        self.windowListPopup.addItem(withTitle: "利用可能なウィンドウがありません")
                        self.startCaptureButton.isEnabled = false
                    } else {
                        for window in filteredWindows {
                            let appName = window.owningApplication?.applicationName ?? "不明"
                            let windowTitle = window.title?.isEmpty == false ? window.title! : "無題"
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
    
    @objc private func refreshButtonClicked(_ sender: NSButton) {
        loadAvailableWindows()
    }
    
    @objc private func transparencySliderChanged(_ sender: NSSlider) {
        updateWindowTransparency()
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
            self.captureImageView.image = image
        }
    }
    
    func didEncounterError(_ error: Error) {
        DispatchQueue.main.async {
            print("キャプチャエラー: \(error)")
            self.startCaptureButton.title = "キャプチャ開始"
        }
    }
}

protocol WindowCaptureManagerDelegate: AnyObject {
    func didReceiveNewFrame(_ image: NSImage)
    func didEncounterError(_ error: Error)
}

@available(macOS 12.3, *)
class WindowCaptureManager: NSObject {
    weak var delegate: WindowCaptureManagerDelegate?
    
    private var captureTimer: Timer?
    private var targetWindow: SCWindow?
    
    func startCapture(for window: SCWindow) {
        targetWindow = window
        
        print("ウィンドウキャプチャ開始:")
        print("  ウィンドウタイトル: \(window.title ?? "不明")")
        print("  アプリ名: \(window.owningApplication?.applicationName ?? "不明")")
        print("  ウィンドウID: \(window.windowID)")
        print("  ウィンドウサイズ: \(window.frame)")
        
        // CGWindowListCreateImageを使用したキャプチャ（確実にウィンドウ単体をキャプチャ）
        captureTimer = Timer.scheduledTimer(withTimeInterval: 1.0/15.0, repeats: true) { [weak self] _ in
            self?.captureWindowImage()
        }
    }
    
    private func captureWindowImage() {
        guard let window = targetWindow else { return }
        
        let windowID = CGWindowID(window.windowID)
        
        // ウィンドウのみを正確にキャプチャ
        guard let cgImage = CGWindowListCreateImage(
            CGRect.null, // ウィンドウの元のサイズを使用
            .optionIncludingWindow,
            windowID,
            [.bestResolution, .boundsIgnoreFraming]
        ) else {
            // 最初の数回のエラーのみログ出力
            static var errorCount = 0
            if errorCount < 3 {
                print("CGWindowListCreateImage失敗 - ウィンドウID: \(windowID)")
                errorCount += 1
            }
            return
        }
        
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        
        // デリゲートに通知
        delegate?.didReceiveNewFrame(nsImage)
    }
    
    func stopCapture() {
        captureTimer?.invalidate()
        captureTimer = nil
        targetWindow = nil
        print("ウィンドウキャプチャ停止完了")
    }
}

// MARK: - Main Entry Point
@available(macOS 12.3, *)
func main() {
    // NSApplicationを初期化
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    
    // AppDelegateを設定
    let appDelegate = AppDelegate()
    app.delegate = appDelegate
    
    // アプリケーションを実行
    app.run()
}

// メイン関数を実行
if #available(macOS 12.3, *) {
    main()
} else {
    print("このアプリケーションにはmacOS 12.3以上が必要です。")
    exit(1)
}
