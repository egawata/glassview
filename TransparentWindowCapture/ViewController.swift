import Cocoa
import ScreenCaptureKit

class ViewController: NSViewController {
    @IBOutlet weak var captureImageView: NSImageView!
    @IBOutlet weak var windowListPopup: NSPopUpButton!
    @IBOutlet weak var startCaptureButton: NSButton!
    @IBOutlet weak var transparencySlider: NSSlider!
    
    private var clickThroughButton: NSButton!
    private var statusLabel: NSTextField!
    private var captureAreaOnlyButton: NSButton!
    private var customImageView: ClickThroughImageView!
    
    private var windowCaptureManager: WindowCaptureManager?
    private var availableWindows: [SCWindow] = []
    private var isClickThroughEnabled = false
    private var isCaptureAreaOnlyMode = false {
        didSet {
            // AppDelegateがアクセスできるように通知を送信
            NotificationCenter.default.post(name: .captureAreaOnlyModeChanged, object: isCaptureAreaOnlyMode)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupWindowTransparency()
        setupWindowCaptureManager()
        setupUIComponents()
        loadAvailableWindows()
        updateStatusLabel()
        
        // 初期透明度設定
        transparencySlider.doubleValue = 0.8
        updateWindowTransparency()
    }
    
    private func setupUIComponents() {
        setupCustomImageView()
        setupClickThroughButton()
        setupCaptureAreaOnlyButton()
        setupStatusLabel()
    }
    
    private func setupCustomImageView() {
        // 既存のImageViewを置き換える
        customImageView = ClickThroughImageView(frame: captureImageView.frame)
        customImageView.translatesAutoresizingMaskIntoConstraints = false
        customImageView.imageScaling = .scaleProportionallyUpOrDown
        
        // 既存のImageViewを削除して新しいものを追加
        captureImageView.removeFromSuperview()
        view.addSubview(customImageView)
        
        // 制約をコピー
        NSLayoutConstraint.activate([
            customImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            customImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            customImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            customImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -120)
        ])
    }
    
    private func setupClickThroughButton() {
        clickThroughButton = NSButton(frame: NSRect(x: 0, y: 0, width: 130, height: 32))
        clickThroughButton.title = "全体クリック無視"
        clickThroughButton.bezelStyle = .rounded
        clickThroughButton.target = self
        clickThroughButton.action = #selector(clickThroughButtonClicked(_:))
        clickThroughButton.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(clickThroughButton)
        
        // 制約を追加
        NSLayoutConstraint.activate([
            clickThroughButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            clickThroughButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -80),
            clickThroughButton.widthAnchor.constraint(equalToConstant: 130)
        ])
    }
    
    private func setupCaptureAreaOnlyButton() {
        captureAreaOnlyButton = NSButton(frame: NSRect(x: 0, y: 0, width: 150, height: 32))
        captureAreaOnlyButton.title = "キャプチャ部のみ無視"
        captureAreaOnlyButton.bezelStyle = .rounded
        captureAreaOnlyButton.target = self
        captureAreaOnlyButton.action = #selector(captureAreaOnlyButtonClicked(_:))
        captureAreaOnlyButton.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(captureAreaOnlyButton)
        
        // 制約を追加
        NSLayoutConstraint.activate([
            captureAreaOnlyButton.leadingAnchor.constraint(equalTo: clickThroughButton.trailingAnchor, constant: 10),
            captureAreaOnlyButton.centerYAnchor.constraint(equalTo: clickThroughButton.centerYAnchor),
            captureAreaOnlyButton.widthAnchor.constraint(equalToConstant: 150)
        ])
    }
    
    private func setupStatusLabel() {
        statusLabel = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 20))
        statusLabel.isEditable = false
        statusLabel.isBordered = false
        statusLabel.backgroundColor = NSColor.clear
        statusLabel.font = NSFont.systemFont(ofSize: 12)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(statusLabel)
        
        // 制約を追加
        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: captureAreaOnlyButton.trailingAnchor, constant: 20),
            statusLabel.centerYAnchor.constraint(equalTo: clickThroughButton.centerYAnchor),
            statusLabel.widthAnchor.constraint(equalToConstant: 250)
        ])
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
    
    @objc private func clickThroughButtonClicked(_ sender: NSButton) {
        toggleClickThrough()
    }
    
    @objc private func captureAreaOnlyButtonClicked(_ sender: NSButton) {
        toggleCaptureAreaOnlyMode()
    }
    
    private func toggleClickThrough() {
        // 全体のクリック透過モードを切り替える
        isClickThroughEnabled.toggle()
        isCaptureAreaOnlyMode = false // 排他的モード
        
        view.window?.ignoresMouseEvents = isClickThroughEnabled
        customImageView?.setClickThroughEnabled(false)
        
        updateButtonTitles()
        updateStatusLabel()
    }
    
    private func toggleCaptureAreaOnlyMode() {
        // キャプチャエリアのみクリック透過モードを切り替える
        isCaptureAreaOnlyMode.toggle()
        isClickThroughEnabled = false // 排他的モード
        
        view.window?.ignoresMouseEvents = false
        customImageView?.setClickThroughEnabled(isCaptureAreaOnlyMode)
        
        updateButtonTitles()
        updateStatusLabel()
    }
    
    // AppDelegateから呼ばれるメソッド
    func toggleCaptureAreaOnlyModePublic() {
        toggleCaptureAreaOnlyMode()
    }
    
    private func updateButtonTitles() {
        clickThroughButton?.title = isClickThroughEnabled ? "全体クリック有効" : "全体クリック無視"
        captureAreaOnlyButton?.title = isCaptureAreaOnlyMode ? "キャプチャ部有効" : "キャプチャ部のみ無視"
    }
    
    // AppDelegateから呼ばれるメソッド
    func updateClickThroughState(_ enabled: Bool) {
        isClickThroughEnabled = enabled
        isCaptureAreaOnlyMode = false
        customImageView?.setClickThroughEnabled(false)
        updateButtonTitles()
        updateStatusLabel()
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
            self.customImageView?.image = image
        }
    }
    
    func didEncounterError(_ error: Error) {
        DispatchQueue.main.async {
            print("キャプチャエラー: \(error)")
            self.startCaptureButton.title = "キャプチャ開始"
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let captureAreaOnlyModeChanged = Notification.Name("captureAreaOnlyModeChanged")
}
