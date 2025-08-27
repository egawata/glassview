import Cocoa
import ScreenCaptureKit

class ViewController: NSViewController {
    @IBOutlet weak var captureImageView: NSImageView!
    @IBOutlet weak var windowListPopup: NSPopUpButton!
    @IBOutlet weak var startCaptureButton: NSButton!
    @IBOutlet weak var transparencySlider: NSSlider!
    
    private var windowCaptureManager: WindowCaptureManager?
    private var availableWindows: [SCWindow] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupWindowTransparency()
        setupWindowCaptureManager()
        loadAvailableWindows()
        
        // 初期透明度設定
        transparencySlider.doubleValue = 0.8
        updateWindowTransparency()
    }
    
    private func setupWindowTransparency() {
        // ウィンドウの背景を透明に設定
        view.window?.backgroundColor = NSColor.clear
        view.window?.isOpaque = false
        view.window?.hasShadow = true
        
        // ウィンドウスタイルを設定
        view.window?.styleMask.insert(.fullSizeContentView)
        view.window?.titlebarAppearsTransparent = true
    }
    
    private func setupWindowCaptureManager() {
        windowCaptureManager = WindowCaptureManager()
        windowCaptureManager?.delegate = self
    }
    
    private func loadAvailableWindows() {
        Task {
            do {
                let content = try await SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true)
                await MainActor.run {
                    self.availableWindows = content.windows.filter { window in
                        // 自分のアプリのウィンドウを除外し、有効なタイトルを持つウィンドウのみ表示
                        return window.title?.isEmpty == false && 
                               window.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier
                    }
                    self.updateWindowListPopup()
                }
            } catch {
                print("ウィンドウリストの取得に失敗しました: \(error)")
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
    
    @IBAction func startCaptureButtonClicked(_ sender: NSButton) {
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
    
    @IBAction func transparencySliderChanged(_ sender: NSSlider) {
        updateWindowTransparency()
    }
    
    @IBAction func refreshWindowListClicked(_ sender: NSButton) {
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
