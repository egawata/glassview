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

// MARK: - App Delegate
@available(macOS 12.3, *)
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    private var statusBarItem: NSStatusItem?
    private var viewController: ViewController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBarItem()
        setupWindow()

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
            // カスタムアイコンを使用（アプリケーションアイコンと同じテイスト）
            if let iconImage = NSImage(named: "StatusBarIcon") {
                // ステータスバー用にサイズを調整
                iconImage.size = NSSize(width: 18, height: 18)
                iconImage.isTemplate = true // ダークモード対応
                button.image = iconImage
            } else {
                // フォールバック：システムシンボル
                button.image = NSImage(systemSymbolName: "video.circle", accessibilityDescription: "GlassView")
            }
            button.toolTip = "GlassView"
        }

        setupStatusBarMenu()
    }

    private func setupStatusBarMenu() {
        let menu = NSMenu()

        // 全てリセットメニューアイテム（一番上）
        let resetAllItem = NSMenuItem(title: "全てリセット", action: #selector(resetAll), keyEquivalent: "")
        resetAllItem.target = self
        menu.addItem(resetAllItem)

        menu.addItem(NSMenuItem.separator())

        // ここから下は従来機能と同じ
        // 常に手前表示の切り替えメニューアイテム
        let alwaysOnTopItem = NSMenuItem(title: "常に手前に表示", action: #selector(toggleAlwaysOnTop), keyEquivalent: "")
        alwaysOnTopItem.target = self
        menu.addItem(alwaysOnTopItem)

        // クリック透過の切り替えメニューアイテム
        let clickThroughItem = NSMenuItem(title: "クリック透過", action: #selector(toggleClickThrough), keyEquivalent: "")
        clickThroughItem.target = self
        menu.addItem(clickThroughItem)

        // 不透明度をリセットメニューアイテム
        let resetOpacityItem = NSMenuItem(title: "不透明度をリセット", action: #selector(resetOpacity), keyEquivalent: "")
        resetOpacityItem.target = self
        menu.addItem(resetOpacityItem)

        menu.addItem(NSMenuItem.separator())

        // ウィンドウを表示メニューアイテム
        let showWindowItem = NSMenuItem(title: "ウィンドウを表示", action: #selector(showMainWindow), keyEquivalent: "")
        showWindowItem.target = self
        menu.addItem(showWindowItem)

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
           let alwaysOnTopItem = menu.item(at: 2) { // インデックスを2に変更（全てリセット、区切り線の後）
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
    }

    // メニューバーのクリック透過の状態を更新するメソッド
    func updateClickThroughMenuState(_ isEnabled: Bool) {
        if let menu = statusBarItem?.menu,
           let clickThroughItem = menu.item(at: 3) { // インデックスを3に変更（全てリセット、区切り線、常に手前の後）
            clickThroughItem.title = "クリック透過"
            clickThroughItem.state = isEnabled ? .on : .off
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

    @objc private func resetAll() {
        // 全てを初期状態に戻す

        // ViewControllerを通して全てをリセット
        viewController?.resetAllToInitialState()

        // 常に手前表示を無効化
        window.level = .normal
        updateAlwaysOnTopMenuState(false)
        viewController?.updateAlwaysOnTopState(false)

        // クリック透過を無効化
        (window as? ClickThroughWindow)?.setGlobalClickThroughEnabled(false)
        updateClickThroughMenuState(false)
        viewController?.updateClickThroughState(false)

        // 不透明度を100%にリセット
        viewController?.resetOpacity()

        // ウィンドウをアクティブにして最前面に表示
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
