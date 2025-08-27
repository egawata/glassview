import Cocoa
import ScreenCaptureKit

@available(macOS 12.3, *)
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var viewController: ViewController!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // ウィンドウを作成
        let rect = NSRect(x: 100, y: 100, width: 800, height: 600)
        window = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Transparent Window Capture"
        window.center()
        
        // ViewControllerを作成して設定
        viewController = ViewController()
        window.contentViewController = viewController
        
        // ウィンドウを表示
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // アプリケーションが終了する時の処理
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
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
        
        // Refresh button
        let refreshButton = NSButton(frame: NSRect(x: 442, y: 41, width: 80, height: 32))
        refreshButton.title = "更新"
        refreshButton.bezelStyle = .rounded
        refreshButton.target = self
        refreshButton.action = #selector(refreshWindowListClicked(_:))
        view.addSubview(refreshButton)
        
        // Transparency label
        let transparencyLabel = NSTextField(frame: NSRect(x: 540, y: 50, width: 45, height: 16))
        transparencyLabel.stringValue = "透明度:"
        transparencyLabel.isEditable = false
        transparencyLabel.isBordered = false
        transparencyLabel.backgroundColor = .clear
        view.addSubview(transparencyLabel)
        
        // Transparency slider
        transparencySlider = NSSlider(frame: NSRect(x: 590, y: 46, width: 190, height: 25))
        transparencySlider.minValue = 0.1
        transparencySlider.maxValue = 1.0
        transparencySlider.doubleValue = 0.8
        transparencySlider.target = self
        transparencySlider.action = #selector(transparencySliderChanged(_:))
        view.addSubview(transparencySlider)
        
        // Info label
        let infoLabel = NSTextField(frame: NSRect(x: 20, y: 20, width: 760, height: 16))
        infoLabel.stringValue = "※ このアプリにはスクリーン録画権限が必要です。システム設定 > プライバシーとセキュリティ > スクリーン録画 で許可してください。"
        infoLabel.isEditable = false
        infoLabel.isBordered = false
        infoLabel.backgroundColor = .clear
        infoLabel.textColor = .secondaryLabelColor
        view.addSubview(infoLabel)
    }
    
    private func setupWindowTransparency() {
        // ウィンドウの背景を透明に設定
        view.window?.backgroundColor = NSColor.clear
        view.window?.isOpaque = false
        view.window?.hasShadow = true
    }
    
    private func setupWindowCaptureManager() {
        windowCaptureManager = WindowCaptureManager()
        windowCaptureManager?.delegate = self
    }
    
    private func loadAvailableWindows() {
        SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { content, error in
            if let error = error {
                print("ウィンドウリストの取得に失敗しました: \(error)")
                return
            }
            
            guard let content = content else {
                print("コンテンツが取得できませんでした")
                return
            }
            
            DispatchQueue.main.async {
                self.availableWindows = content.windows.filter { window in
                    // 自分のアプリのウィンドウを除外し、有効なタイトルを持つウィンドウのみ表示
                    return window.title?.isEmpty == false && 
                           window.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier
                }
                self.updateWindowListPopup()
            }
        }
    }
    
    private func updateWindowListPopup() {
        windowListPopup.removeAllItems()
        windowListPopup.addItem(withTitle: "ウィンドウを選択してください")
        
        for window in availableWindows {
            let title = window.title ?? "無題のウィンドウ"
            let appName = window.owningApplication?.applicationName ?? "不明なアプリ"
            windowListPopup.addItem(withTitle: "\(appName) - \(title)")
        }
    }
    
    @objc func startCaptureButtonClicked(_ sender: NSButton) {
        guard windowListPopup.indexOfSelectedItem > 0,
              windowListPopup.indexOfSelectedItem <= availableWindows.count else {
            return
        }
        
        let selectedWindow = availableWindows[windowListPopup.indexOfSelectedItem - 1]
        
        if sender.title == "キャプチャ開始" {
            startWindowCapture(for: selectedWindow)
            sender.title = "キャプチャ停止"
        } else {
            stopWindowCapture()
            sender.title = "キャプチャ開始"
        }
    }
    
    @objc func transparencySliderChanged(_ sender: NSSlider) {
        updateWindowTransparency()
    }
    
    @objc func refreshWindowListClicked(_ sender: NSButton) {
        loadAvailableWindows()
    }
    
    private func startWindowCapture(for window: SCWindow) {
        windowCaptureManager?.startCapture(for: window)
    }
    
    private func stopWindowCapture() {
        windowCaptureManager?.stopCapture()
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
class WindowCaptureManager: NSObject, SCStreamDelegate, SCStreamOutput {
    weak var delegate: WindowCaptureManagerDelegate?
    
    private var stream: SCStream?
    private var streamConfiguration: SCStreamConfiguration?
    
    func startCapture(for window: SCWindow) {
        Task {
            do {
                // ストリーム設定を作成
                let configuration = SCStreamConfiguration()
                configuration.width = Int(window.frame.width)
                configuration.height = Int(window.frame.height)
                configuration.pixelFormat = kCVPixelFormatType_32BGRA
                configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30) // 30 FPS
                configuration.queueDepth = 3
                
                // フィルターを作成（選択されたウィンドウのみ）
                let filter = SCContentFilter(desktopIndependentWindow: window)
                
                // ストリームを作成
                stream = SCStream(filter: filter, configuration: configuration, delegate: self)
                
                // 出力を追加
                try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: DispatchQueue.global(qos: .userInteractive))
                
                // ストリーミング開始
                try await stream?.startCapture()
                
                streamConfiguration = configuration
                
            } catch {
                delegate?.didEncounterError(error)
            }
        }
    }
    
    func stopCapture() {
        Task {
            do {
                try await stream?.stopCapture()
                stream = nil
                streamConfiguration = nil
            } catch {
                delegate?.didEncounterError(error)
            }
        }
    }
    
    // MARK: - SCStreamOutput
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        // CVPixelBufferからNSImageに変換
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return
        }
        
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        
        // メインスレッドでデリゲートに通知
        DispatchQueue.main.async {
            self.delegate?.didReceiveNewFrame(nsImage)
        }
    }
    
    // MARK: - SCStreamDelegate
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        delegate?.didEncounterError(error)
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
