import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarItem: NSStatusItem?
    private var mainViewController: ViewController?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // メニューバーアイテムを作成
        setupStatusBarItem()
        
        // メインウィンドウのViewControllerへの参照を取得
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first,
               let viewController = window.contentViewController as? ViewController {
                self.mainViewController = viewController
            }
        }
        
        // 通知を監視
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(captureAreaOnlyModeChanged(_:)),
            name: .captureAreaOnlyModeChanged,
            object: nil
        )
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // アプリケーションが終了する時の処理
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
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
        guard let mainWindow = NSApplication.shared.windows.first else { return }
        
        let isCurrentlyClickThrough = mainWindow.ignoresMouseEvents
        mainWindow.ignoresMouseEvents = !isCurrentlyClickThrough
        
        // メニューアイテムのタイトルを更新
        if let menu = statusBarItem?.menu,
           let clickThroughItem = menu.item(at: 0) {
            clickThroughItem.title = isCurrentlyClickThrough ? "全体クリックを無視する" : "全体クリックを有効にする"
            clickThroughItem.state = isCurrentlyClickThrough ? .off : .on
        }
        
        // ViewControllerに状態を通知
        mainViewController?.updateClickThroughState(!isCurrentlyClickThrough)
    }
    
    @objc private func toggleCaptureAreaOnly() {
        // ViewControllerのキャプチャエリアのみクリック無視を切り替え
        mainViewController?.toggleCaptureAreaOnlyModePublic()
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
        if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
