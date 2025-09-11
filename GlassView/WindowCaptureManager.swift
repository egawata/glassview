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
import os.log

// MARK: - WindowCaptureManager Protocol
protocol WindowCaptureManagerDelegate: AnyObject {
    func didReceiveNewFrame(_ image: NSImage)
    func didEncounterError(_ error: Error)
    func captureStateDidChange(_ isActive: Bool)
}

// MARK: - WindowCaptureManager
@available(macOS 12.3, *)
class WindowCaptureManager: NSObject, @unchecked Sendable {
    weak var delegate: WindowCaptureManagerDelegate?

    private var captureTimer: Timer?
    private var selectedWindow: SCWindow?
    private var targetWindow: NSWindow?
    private var isCapturePaused = false
    private var lastFrameRate: Double = 30.0
    private var reducedFrameRate: Double = 1.0 // 部分的に見えている時の低フレームレート

    private let logger = Logger(subsystem: "com.example.GlassView", category: "WindowCapture")

    func startCapture(for window: SCWindow, frameRate: Double = 30.0) {
        selectedWindow = window
        lastFrameRate = frameRate

        // キャプチャを開始
        startCaptureTimer()

        // ウィンドウ状態の監視を開始
        setupWindowStateMonitoring()
    }

    func setTargetWindow(_ window: NSWindow) {
        targetWindow = window
    }

    private func startCaptureTimer() {
        guard !isCapturePaused else { return }

        let interval = 1.0 / lastFrameRate
        captureTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            self.captureFrame()
        }
    }

    func stopCapture() {
        captureTimer?.invalidate()
        captureTimer = nil
        selectedWindow = nil
        isCapturePaused = false

        // 通知の監視を停止
        NotificationCenter.default.removeObserver(self)
        DistributedNotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func updateFrameRate(_ frameRate: Double) {
        guard selectedWindow != nil else { return }

        lastFrameRate = frameRate

        // 現在のキャプチャを停止
        captureTimer?.invalidate()

        // 新しいフレームレートでキャプチャを再開
        startCaptureTimer()
    }

    // MARK: - Window State Monitoring
    private func setupWindowStateMonitoring() {
        // アプリケーションのアクティブ状態監視
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )

        // スクリーンセーバー監視
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(screenSaverDidStart),
            name: NSNotification.Name("com.apple.screensaver.didstart"),
            object: nil
        )

        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(screenSaverDidStop),
            name: NSNotification.Name("com.apple.screensaver.didstop"),
            object: nil
        )

        // ワークスペース変更監視
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceDidChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )

        // ウィンドウのocclusion state監視
        if let window = targetWindow {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowOcclusionStateChanged),
                name: NSWindow.didChangeOcclusionStateNotification,
                object: window
            )
        }
    }

    @objc private func applicationDidBecomeActive() {
        resumeCaptureIfNeeded()
    }

    @objc private func applicationDidResignActive() {
        // 透明ウィンドウアプリなので、アプリが非アクティブになっても
        // ウィンドウが見えている限りはキャプチャを続行
        #if DEBUG
        logger.debug("🔄 アプリが非アクティブになりましたが、ウィンドウ状態をチェックして継続判断します")
        #endif
        checkWindowVisibility()
    }

    @objc private func screenSaverDidStart() {
        pauseCapture(reason: "スクリーンセーバーが開始されました")
    }

    @objc private func screenSaverDidStop() {
        resumeCaptureIfNeeded()
    }

    @objc private func workspaceDidChange() {
        // ワークスペースが変更された時の処理
        checkWindowVisibility()
    }

    @objc private func windowOcclusionStateChanged() {
        checkWindowVisibility()
    }

    private func checkWindowVisibility() {
        guard let window = targetWindow else { return }

        DispatchQueue.main.async { [weak self] in
            let isVisible = window.occlusionState.contains(.visible)
            let isOnActiveSpace = window.isOnActiveSpace
            let isAppActive = NSApplication.shared.isActive

            // より詳細な可視性チェック
            let visibilityState = self?.getDetailedVisibilityState(window: window) ?? .hidden

            switch visibilityState {
            case .fullyVisible:
                #if DEBUG
                self?.logger.debug("👁️ ウィンドウが完全に見えています - 通常フレームレートで継続")
                #endif
                self?.resumeCaptureIfNeeded(frameRate: self?.lastFrameRate ?? 30.0)

            case .partiallyVisible:
                #if DEBUG
                self?.logger.debug("👁️‍🗨️ ウィンドウが部分的に見えています - 低フレームレートで継続")
                #endif
                self?.resumeCaptureIfNeeded(frameRate: self?.reducedFrameRate ?? 1.0)

            case .hidden:
                self?.pauseCapture(reason: "ウィンドウが見えない状態です (visible: \(isVisible), activeSpace: \(isOnActiveSpace), appActive: \(isAppActive))")
            }
        }
    }

    private enum WindowVisibilityState {
        case fullyVisible
        case partiallyVisible
        case hidden
    }

    private func getDetailedVisibilityState(window: NSWindow) -> WindowVisibilityState {
        // 基本的な可視性チェック
        guard window.occlusionState.contains(.visible) && window.isOnActiveSpace else {
            return .hidden
        }

        // ウィンドウがフルスクリーンまたは十分に大きく表示されているかチェック
        let windowFrame = window.frame
        let screenFrame = window.screen?.frame ?? NSScreen.main?.frame ?? .zero

        // ウィンドウの面積と画面の面積を比較
        let windowArea = windowFrame.width * windowFrame.height
        let screenArea = screenFrame.width * screenFrame.height
        let visibleRatio = windowArea / screenArea

        // 画面の30%以上を占める場合は完全に見えているとみなす
        if visibleRatio > 0.3 {
            return .fullyVisible
        }
        // 5%以上なら部分的に見えている
        else if visibleRatio > 0.05 {
            return .partiallyVisible
        }
        // それ以外は隠れているとみなす
        else {
            return .hidden
        }
    }

    private func pauseCapture(reason: String) {
        guard !isCapturePaused else { return }

        isCapturePaused = true
        captureTimer?.invalidate()
        captureTimer = nil

        #if DEBUG
        logger.debug("🛑 キャプチャを一時停止: \(reason)")
        #endif
        delegate?.captureStateDidChange(false)
    }

    private func resumeCaptureIfNeeded(frameRate: Double? = nil) {
        guard isCapturePaused else {
            // 既に動作中の場合は、フレームレートだけ更新
            if let newFrameRate = frameRate, newFrameRate != lastFrameRate {
                updateFrameRate(newFrameRate)
            }
            return
        }
        guard selectedWindow != nil else { return }

        // フレームレートが指定されていれば更新
        if let newFrameRate = frameRate {
            lastFrameRate = newFrameRate
        }

        // 本当に再開すべきかチェック
        if let window = targetWindow {
            let isVisible = window.occlusionState.contains(.visible)
            let isOnActiveSpace = window.isOnActiveSpace
            let isAppActive = NSApplication.shared.isActive

            // 透明ウィンドウアプリの場合、ウィンドウが見えて、アクティブスペースにあれば再開
            // アプリがアクティブかどうかは考慮しない
            guard isVisible && isOnActiveSpace else {
                #if DEBUG
                logger.debug("🔍 再開条件が満たされていません (visible: \(isVisible), activeSpace: \(isOnActiveSpace), appActive: \(isAppActive))")
                #endif
                return
            }
        }

        isCapturePaused = false
        startCaptureTimer()

        #if DEBUG
        logger.debug("▶️ キャプチャを再開しました (フレームレート: \(self.lastFrameRate)fps)")
        #endif
        delegate?.captureStateDidChange(true)
    }

    private func captureFrame() {
        guard let window = selectedWindow else { return }
        guard !isCapturePaused else { return } // 一時停止中はキャプチャしない

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
