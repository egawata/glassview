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

// MARK: - App Delegate
@available(macOS 12.3, *)
class AppDelegate: NSObject, NSApplicationDelegate, ControlPanelDelegate {
    var window: NSWindow!
    var controlPanelWindow: NSWindow!
    private var viewController: ViewController?
    private var controlPanelController: ControlPanelViewController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupWindow()
        setupControlPanelWindow()
        setupMainMenu()
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // アプリケーションメニュー
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()

        // 終了
        let quitItem = NSMenuItem(title: "終了", action: #selector(quitApplication), keyEquivalent: "q")
        quitItem.target = self
        quitItem.keyEquivalentModifierMask = [.command]
        appMenu.addItem(quitItem)

        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // 表示メニュー
        let viewMenuItem = NSMenuItem(title: "表示", action: nil, keyEquivalent: "")
        let viewMenu = NSMenu(title: "表示")

        // 全てリセット
        let resetAllItem = NSMenuItem(title: "全てリセット", action: #selector(resetAll), keyEquivalent: "r")
        resetAllItem.target = self
        resetAllItem.keyEquivalentModifierMask = [.command]
        viewMenu.addItem(resetAllItem)

        viewMenu.addItem(NSMenuItem.separator())

        // 常に手前に表示
        let alwaysOnTopMenuItem = NSMenuItem(title: "常に手前に表示", action: #selector(toggleAlwaysOnTop), keyEquivalent: "f")
        alwaysOnTopMenuItem.target = self
        alwaysOnTopMenuItem.keyEquivalentModifierMask = [.command]
        viewMenu.addItem(alwaysOnTopMenuItem)

        // クリック透過
        let clickThroughMenuItem = NSMenuItem(title: "クリック透過", action: #selector(toggleClickThrough), keyEquivalent: "t")
        clickThroughMenuItem.target = self
        clickThroughMenuItem.keyEquivalentModifierMask = [.command]
        viewMenu.addItem(clickThroughMenuItem)

        viewMenu.addItem(NSMenuItem.separator())

        // 不透明度をリセット
        let resetOpacityMenuItem = NSMenuItem(title: "不透明度をリセット", action: #selector(resetOpacity), keyEquivalent: "o")
        resetOpacityMenuItem.target = self
        resetOpacityMenuItem.keyEquivalentModifierMask = [.command]
        viewMenu.addItem(resetOpacityMenuItem)

        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        // ウィンドウメニュー
        let windowMenuItem = NSMenuItem(title: "ウィンドウ", action: nil, keyEquivalent: "")
        let windowMenu = NSMenu(title: "ウィンドウ")

        // ウィンドウを表示
        let showWindowMenuItem = NSMenuItem(title: "ウィンドウを表示", action: #selector(showMainWindow), keyEquivalent: "w")
        showWindowMenuItem.target = self
        showWindowMenuItem.keyEquivalentModifierMask = [.command]
        windowMenu.addItem(showWindowMenuItem)

        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApplication.shared.mainMenu = mainMenu

        // 初期状態を更新
        updateAllMenuStates()
    }

    // 全てのメニュー状態を現在の設定と同期
    private func updateAllMenuStates() {
        let isAlwaysOnTop = window.level == .floating
        let isClickThrough = (window as? ClickThroughWindow)?.isGlobalClickThroughEnabled ?? false

        updateAlwaysOnTopMenuState(isAlwaysOnTop)
        updateClickThroughMenuState(isClickThrough)

        // コントロールパネルの状態も同期
        controlPanelController?.updateAlwaysOnTopState(isAlwaysOnTop)
        controlPanelController?.updateClickThroughState(isClickThrough)
    }

    @objc private func toggleAlwaysOnTop() {
        let currentLevel = window.level
        let isCurrentlyOnTop = currentLevel == .floating

        window.level = isCurrentlyOnTop ? .normal : .floating
        updateAlwaysOnTopMenuState(!isCurrentlyOnTop)
        viewController?.updateAlwaysOnTopState(!isCurrentlyOnTop)
        controlPanelController?.updateAlwaysOnTopState(!isCurrentlyOnTop)
    }

    // メインメニューの常に手前表示の状態を更新
    private func updateAlwaysOnTopMenuState(_ isEnabled: Bool) {
        if let mainMenu = NSApplication.shared.mainMenu,
           let viewMenu = mainMenu.item(at: 1)?.submenu,
           let alwaysOnTopItem = viewMenu.item(at: 2) {
            alwaysOnTopItem.state = isEnabled ? .on : .off
        }
    }

    @objc private func toggleClickThrough() {
        let isCurrentlyClickThrough = (window as? ClickThroughWindow)?.isGlobalClickThroughEnabled ?? false

        (window as? ClickThroughWindow)?.setGlobalClickThroughEnabled(!isCurrentlyClickThrough)
        updateClickThroughMenuState(!isCurrentlyClickThrough)
        viewController?.updateClickThroughState(!isCurrentlyClickThrough)
        controlPanelController?.updateClickThroughState(!isCurrentlyClickThrough)
    }

    // メインメニューのクリック透過の状態を更新
    private func updateClickThroughMenuState(_ isEnabled: Bool) {
        if let mainMenu = NSApplication.shared.mainMenu,
           let viewMenu = mainMenu.item(at: 1)?.submenu,
           let clickThroughItem = viewMenu.item(at: 3) {
            clickThroughItem.state = isEnabled ? .on : .off
        }
    }

    @objc private func showMainWindow() {
        window.makeKeyAndOrderFront(nil)
        controlPanelWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApplication() {
        NSApplication.shared.terminate(nil)
    }

    @objc private func resetOpacity() {
        viewController?.updateWindowTransparency(1.0)
        controlPanelController?.updateTransparencyValue(1.0)
    }

    @objc private func resetAll() {
        viewController?.resetAllToInitialState()
        controlPanelController?.updateTransparencyValue(1.0)
        controlPanelController?.updateClickThroughState(false)
        controlPanelController?.updateAlwaysOnTopState(false)

        // 常に手前表示を無効化
        window.level = .normal
        updateAlwaysOnTopMenuState(false)

        // クリック透過を無効化
        (window as? ClickThroughWindow)?.setGlobalClickThroughEnabled(false)
        updateClickThroughMenuState(false)

        // ウィンドウをアクティブにして最前面に表示
        window.makeKeyAndOrderFront(nil)
        controlPanelWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupWindow() {
        let contentRect = NSRect(x: 0, y: 0, width: 800, height: 600)

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

    private func setupControlPanelWindow() {
        let contentRect = NSRect(x: 0, y: 0, width: 800, height: 200) // 高さを180から200に変更

        controlPanelWindow = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        controlPanelWindow.title = "GlassView Control Panel"

        // メインウィンドウの右側に配置
        let mainWindowFrame = window.frame
        let controlPanelFrame = NSRect(
            x: mainWindowFrame.maxX + 20,
            y: mainWindowFrame.maxY - 200, // 高さ変更に合わせて調整
            width: 800,
            height: 200 // 高さを180から200に変更
        )
        controlPanelWindow.setFrame(controlPanelFrame, display: true)

        let controlPanelController = ControlPanelViewController()
        controlPanelController.delegate = self
        controlPanelWindow.contentViewController = controlPanelController
        self.controlPanelController = controlPanelController

        controlPanelWindow.makeKeyAndOrderFront(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// MARK: - ControlPanelDelegate Implementation
@available(macOS 12.3, *)
extension AppDelegate {
    func controlPanel(_ panel: ControlPanelViewController, didStartCapture window: SCWindow, frameRate: Double) {
        viewController?.startCapture(for: window, frameRate: frameRate)
    }

    func controlPanelDidStopCapture(_ panel: ControlPanelViewController) {
        viewController?.stopCapture()
    }

    func controlPanelDidRefreshWindowList(_ panel: ControlPanelViewController) {
        // 必要に応じて追加の処理
    }

    func controlPanel(_ panel: ControlPanelViewController, didChangeTransparency alpha: Double) {
        viewController?.updateWindowTransparency(alpha)
    }

    func controlPanel(_ panel: ControlPanelViewController, didChangeFrameRate frameRate: Double) {
        viewController?.updateFrameRate(frameRate)
    }

    func controlPanel(_ panel: ControlPanelViewController, didToggleClickThrough enabled: Bool) {
        (window as? ClickThroughWindow)?.setGlobalClickThroughEnabled(enabled)
        viewController?.updateClickThroughState(enabled)
        updateClickThroughMenuState(enabled)
    }

    func controlPanel(_ panel: ControlPanelViewController, didToggleAlwaysOnTop enabled: Bool) {
        window.level = enabled ? .floating : .normal
        viewController?.updateAlwaysOnTopState(enabled)
        updateAlwaysOnTopMenuState(enabled)
    }

    // MARK: - Transform Delegate Methods
    func controlPanelDidZoomIn(_ panel: ControlPanelViewController) {
        viewController?.zoomIn()
    }

    func controlPanelDidZoomOut(_ panel: ControlPanelViewController) {
        viewController?.zoomOut()
    }

    func controlPanelDidResetTransform(_ panel: ControlPanelViewController) {
        viewController?.resetTransform()
    }
}
