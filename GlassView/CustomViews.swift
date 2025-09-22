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
import os.log

// MARK: - Custom Image View for Click-Through
@available(macOS 12.3, *)
class ClickThroughImageView: NSImageView {
    var isClickThroughEnabled = false

    // Logger for debug output
    private let logger = Logger(subsystem: "com.example.GlassView", category: "ImageView")

    // Transform properties
    private var currentScale: CGFloat = 1.0
    private var minScale: CGFloat = 0.1
    private var maxScale: CGFloat = 5.0
    private var scaleStep: CGFloat = 0.1

    // Pan (move) properties
    private var currentTranslation = CGPoint(x: 0, y: 0)
    private var isDragging = false
    private var lastPanPoint = CGPoint.zero
    private var isSpaceKeyPressed = false

    // Cursor state properties (read-only access for EventForwardingView)
    var shouldShowPanCursor: Bool {
        return window?.isMainWindow == true && isSpaceKeyPressed && !isClickThroughEnabled
    }

    var isPanDragging: Bool {
        return isDragging
    }

    // Global event monitors for space key tracking
    private var keyDownMonitor: Any?
    private var keyUpMonitor: Any?
    private var localKeyDownMonitor: Any?
    private var localKeyUpMonitor: Any?

    override func awakeFromNib() {
        super.awakeFromNib()
        setupTransformProperties()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTransformProperties()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTransformProperties()
    }

    private func setupTransformProperties() {
        // Enable layer-backed view for Core Animation transforms
        wantsLayer = true
        layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)

        // Setup global key event monitors for space key
        setupSpaceKeyMonitors()

        // ウィンドウのアクティブ状態変更を監視
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeMain),
            name: NSWindow.didBecomeMainNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResignMain),
            name: NSWindow.didResignMainNotification,
            object: nil
        )

        #if DEBUG
        // デバッグログ: セットアップ情報を記録
        logger.debug("🎯 ClickThroughImageView setup completed")
        logger.debug("  - frame: \(String(describing: self.frame))")
        logger.debug("  - bounds: \(String(describing: self.bounds))")
        logger.debug("  - wantsLayer: \(self.wantsLayer)")
        logger.debug("  - acceptsFirstResponder: \(self.acceptsFirstResponder)")
        #endif
    }

    override var acceptsFirstResponder: Bool {
        #if DEBUG
        logger.debug("🎯 ClickThroughImageView acceptsFirstResponder called -> return \(!self.isClickThroughEnabled)")
        #endif
        return !isClickThroughEnabled
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        #if DEBUG
        logger.debug("🎯 ClickThroughImageView becomeFirstResponder called -> return \(result)")
        #endif
        return result
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let result = isClickThroughEnabled ? nil : super.hitTest(point)
        #if DEBUG
        logger.debug("🎯 ClickThroughImageView hitTest called")
        logger.debug("  - point: \(String(describing: point))")
        logger.debug("  - clickThrough enabled: \(self.isClickThroughEnabled)")
        logger.debug("  - result: \(result != nil ? "self" : "nil")")
        logger.debug("  - frame: \(String(describing: self.frame))")
        logger.debug("  - bounds: \(String(describing: self.bounds))")
        #endif
        return result
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        // クリック透過が有効な場合は、マウスクリックを受け入れない
        return !isClickThroughEnabled
    }

    // MARK: - Cursor Management
    override func resetCursorRects() {
        super.resetCursorRects()

        // メインウィンドウがアクティブで、かつSpaceキーが押されている時のみカーソルを変更
        if window?.isMainWindow == true && isSpaceKeyPressed && !isClickThroughEnabled {
            if isDragging {
                addCursorRect(bounds, cursor: .closedHand)
            } else {
                addCursorRect(bounds, cursor: .openHand)
            }
        } else {
            addCursorRect(bounds, cursor: .arrow)
        }
    }

    private func updateCursor() {
        // カーソル矩形を再計算してカーソルを更新
        window?.invalidateCursorRects(for: self)
        discardCursorRects()
        resetCursorRects()

        // EventForwardingViewにも通知
        updateEventForwardingViewCursor()
    }

    private func updateEventForwardingViewCursor() {
        // 親ビューでEventForwardingViewを探して、カーソルを更新
        guard let parentView = superview?.superview else { return }

        for subview in parentView.subviews {
            if let eventForwardingView = subview as? EventForwardingView {
                eventForwardingView.window?.invalidateCursorRects(for: eventForwardingView)
                eventForwardingView.discardCursorRects()
                eventForwardingView.resetCursorRects()
            }
        }
    }

    // MARK: - Window State Notification Handlers
    @objc private func windowDidBecomeMain(_ notification: Notification) {
        #if DEBUG
        logger.debug("🏠 Window became main - updating cursor")
        #endif
        updateCursor()
    }

    @objc private func windowDidResignMain(_ notification: Notification) {
        #if DEBUG
        logger.debug("🏠 Window resigned main - updating cursor")
        #endif
        updateCursor()
    }

    override func mouseDown(with event: NSEvent) {
        #if DEBUG
        // デバッグログ: mouseDownメソッドが呼ばれたことを記録
        logger.debug("🖱️ mouseDown called on ClickThroughImageView")
        logger.debug("  - clickThrough enabled: \(self.isClickThroughEnabled)")
        logger.debug("  - modifierFlags: \(String(describing: event.modifierFlags))")
        logger.debug("  - isSpaceKeyPressed: \(self.isSpaceKeyPressed)")
        logger.debug("  - current translation: \(String(describing: self.currentTranslation))")
        logger.debug("  - isFirstResponder: \(self.window?.firstResponder == self)")
        logger.debug("  - window.firstResponder: \(String(describing: self.window?.firstResponder))")
        #endif

        if !isClickThroughEnabled {
            // マウスクリック時にFirst Responderになるよう明示的に要求
            if self.window?.firstResponder != self {
                let didBecomeFirstResponder = self.window?.makeFirstResponder(self) ?? false
                #if DEBUG
                logger.debug("🎯 Attempting to become first responder: \(didBecomeFirstResponder)")
                #endif
            }

            // Spaceキーが押されている場合は移動モード
            if isSpaceKeyPressed {
                isDragging = true
                lastPanPoint = event.locationInWindow
                updateCursor() // カーソルを閉じた手のマークに変更
                #if DEBUG
                logger.debug("🖐️ Pan mode started at: \(String(describing: self.lastPanPoint))")
                logger.debug("🖐️ isDragging set to: \(self.isDragging)")
                #endif
                return
            }
            super.mouseDown(with: event)
        }
        // クリック透過が有効な場合は何もしない
    }

    override func mouseUp(with event: NSEvent) {
        if !isClickThroughEnabled {
            if isDragging {
                isDragging = false
                updateCursor() // カーソルを開いた手のマークに戻す
                #if DEBUG
                logger.debug("🖐️ Pan mode ended")
                #endif
                return
            }
            super.mouseUp(with: event)
        }
        // クリック透過が有効な場合は何もしない
    }

    override func mouseDragged(with event: NSEvent) {
        if !isClickThroughEnabled {
            #if DEBUG
            logger.debug("🖱️ mouseDragged called")
            logger.debug("  - isDragging: \(self.isDragging)")
            logger.debug("  - isSpaceKeyPressed: \(self.isSpaceKeyPressed)")
            #endif

            if isDragging {
                let currentPoint = event.locationInWindow
                let deltaX = currentPoint.x - lastPanPoint.x
                let deltaY = currentPoint.y - lastPanPoint.y

                #if DEBUG
                logger.debug("🖐️ Panning: raw delta(\(deltaX), \(deltaY))")
                logger.debug("🖐️ Current scale: \(self.currentScale)")
                logger.debug("🖐️ Current translation BEFORE: \(String(describing: self.currentTranslation))")
                #endif

                // 移動量を現在のスケール（拡大率）で割って調整
                // 拡大率が高いほど移動量を小さくして、直感的な操作感を実現
                let scaledDeltaX = deltaX / currentScale
                let scaledDeltaY = deltaY / currentScale

                // 移動量を現在の移動位置に追加
                currentTranslation.x += scaledDeltaX
                currentTranslation.y += scaledDeltaY

                #if DEBUG
                logger.debug("🖐️ Scaled delta(\(scaledDeltaX), \(scaledDeltaY))")
                logger.debug("🖐️ Current translation AFTER: \(String(describing: self.currentTranslation))")
                #endif

                lastPanPoint = currentPoint
                applyTransform()
                return
            }
            super.mouseDragged(with: event)
        }
        // クリック透過が有効な場合は何もしない
    }

    override func keyDown(with event: NSEvent) {
        #if DEBUG
        logger.debug("⌨️ keyDown: keyCode=\(event.keyCode), characters=\(String(describing: event.characters))")
        #endif

        // Spaceキー (keyCode: 49) の検出
        if event.keyCode == 49 {
            isSpaceKeyPressed = true
            updateCursor() // カーソルを開いた手のマークに変更
            #if DEBUG
            logger.debug("🔘 Space key pressed - pan mode enabled")
            #endif
            return
        }

        super.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        #if DEBUG
        logger.debug("⌨️ keyUp: keyCode=\(event.keyCode), characters=\(String(describing: event.characters))")
        #endif

        // Spaceキー (keyCode: 49) のリリース
        if event.keyCode == 49 {
            isSpaceKeyPressed = false
            isDragging = false
            updateCursor() // カーソルを通常の矢印に戻す
            #if DEBUG
            logger.debug("🔘 Space key released - pan mode disabled")
            #endif
            return
        }

        super.keyUp(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        #if DEBUG
        // デバッグログ: scrollWheelメソッドが呼ばれたことを記録
        logger.debug("🖱️ ClickThroughImageView.scrollWheel called - THIS IS VERY IMPORTANT!")
        logger.debug("  - scrollingDeltaY: \(event.scrollingDeltaY)")
        logger.debug("  - deltaY: \(event.deltaY)")
        logger.debug("  - deltaX: \(event.deltaX)")
        logger.debug("  - modifierFlags: \(String(describing: event.modifierFlags))")
        logger.debug("  - shift pressed: \(event.modifierFlags.contains(.shift))")
        logger.debug("  - clickThrough enabled: \(self.isClickThroughEnabled)")
        #endif

        // Shiftキーが押されている場合のみ拡大縮小を行う
        if event.modifierFlags.contains(.shift) && !isClickThroughEnabled {
            #if DEBUG
            logger.debug("  ✅ Shift+scroll zoom condition met!")
            #endif

            // 複数のdelta値を試す（scrollingDeltaY、deltaY、deltaXの順）
            var deltaY = event.scrollingDeltaY
            if abs(deltaY) < 0.1 {
                deltaY = event.deltaY
            }
            if abs(deltaY) < 0.1 {
                deltaY = event.deltaX
            }

            #if DEBUG
            logger.debug("  - final deltaY used: \(deltaY)")
            #endif

            // マウスホイールの向きに応じて拡大・縮小（小さなステップで）
            let wheelZoomStep: CGFloat = 0.02  // 通常の0.1の0.2倍
            if deltaY > 0.1 {
                // 上にスクロール -> 拡大
                #if DEBUG
                logger.debug("  📈 Zooming IN (deltaY: \(deltaY), step: \(wheelZoomStep))")
                #endif
                zoomIn(step: wheelZoomStep)
            } else if deltaY < -0.1 {
                // 下にスクロール -> 縮小
                #if DEBUG
                logger.debug("  📉 Zooming OUT (deltaY: \(deltaY), step: \(wheelZoomStep))")
                #endif
                zoomOut(step: wheelZoomStep)
            } else {
                #if DEBUG
                logger.debug("  ⚠️ No significant deltaY change (deltaY: \(deltaY))")
                #endif
            }

            // イベントを消費して、他のビューに伝播しないようにする
            return
        } else {
            #if DEBUG
            logger.debug("  ❌ Shift+scroll zoom condition NOT met")
            #endif
        }

        // Shiftキーが押されていない場合は通常の処理
        #if DEBUG
        logger.debug("  → Passing to super.scrollWheel")
        #endif
        super.scrollWheel(with: event)
    }

    func setClickThroughEnabled(_ enabled: Bool) {
        isClickThroughEnabled = enabled
        needsDisplay = true
    }

    // MARK: - Transform Methods
    func zoomIn(step: CGFloat? = nil) {
        let stepToUse = step ?? scaleStep
        let newScale = min(currentScale * (1.0 + stepToUse), maxScale)
        #if DEBUG
        logger.debug("🔍 zoomIn: \(self.currentScale) → \(newScale) (step: \(stepToUse))")
        #endif
        setScale(newScale)
    }

    func zoomOut(step: CGFloat? = nil) {
        let stepToUse = step ?? scaleStep
        let newScale = max(currentScale * (1.0 - stepToUse), minScale)
        #if DEBUG
        logger.debug("🔍 zoomOut: \(self.currentScale) → \(newScale) (step: \(stepToUse))")
        #endif
        setScale(newScale)
    }

    func setScale(_ scale: CGFloat) {
        let oldScale = currentScale
        currentScale = max(minScale, min(scale, maxScale))
        #if DEBUG
        logger.debug("📏 setScale: \(oldScale) → \(self.currentScale) (requested: \(scale))")
        #endif
        applyTransform()
    }

    func resetTransform() {
        currentScale = 1.0
        currentTranslation = CGPoint(x: 0, y: 0)
        #if DEBUG
        logger.debug("🔄 Reset transform: scale=1.0, translation=(0,0)")
        #endif
        applyTransform()
    }

    func resetTransformOnly() {
        // 値は保持したまま、Core Animationのトランスフォームだけをリセット
        guard let layer = layer else { return }

        #if DEBUG
        logger.debug("🔄 Reset transform only (keeping scale: \(self.currentScale), translation: \(String(describing: self.currentTranslation)))")
        #endif

        CATransaction.begin()
        CATransaction.setDisableActions(true) // アニメーションを無効化
        layer.transform = CATransform3DIdentity
        CATransaction.commit()
    }

    func getCurrentScale() -> CGFloat {
        return currentScale
    }

    // MARK: - Pan (Move) Methods
    func panBy(deltaX: CGFloat, deltaY: CGFloat) {
        currentTranslation.x += deltaX
        currentTranslation.y += deltaY
        #if DEBUG
        logger.debug("📍 panBy: \(deltaX), \(deltaY) -> total: \(String(describing: self.currentTranslation))")
        #endif
        applyTransform()
    }

    func setPanPosition(x: CGFloat, y: CGFloat) {
        currentTranslation.x = x
        currentTranslation.y = y
        #if DEBUG
        logger.debug("📍 setPanPosition: \(String(describing: self.currentTranslation))")
        #endif
        applyTransform()
    }

    func getCurrentTranslation() -> CGPoint {
        return currentTranslation
    }

    private func applyTransform() {
        guard let layer = layer else {
            #if DEBUG
            logger.debug("❌ applyTransform: no layer found!")
            #endif
            return
        }

        #if DEBUG
        logger.debug("🔄 applyTransform called:")
        logger.debug("  - currentScale: \(self.currentScale)")
        logger.debug("  - currentTranslation: \(String(describing: self.currentTranslation))")
        logger.debug("  - layer: \(String(describing: layer))")
        #endif

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.2)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))

        // スケールと移動を組み合わせたトランスフォーム
        var transform = CATransform3DMakeScale(currentScale, currentScale, 1.0)
        transform = CATransform3DTranslate(transform, currentTranslation.x, currentTranslation.y, 0)

        #if DEBUG
        logger.debug("  - applying transform with translation: (\(self.currentTranslation.x), \(self.currentTranslation.y))")
        #endif

        layer.transform = transform

        CATransaction.commit()

        #if DEBUG
        logger.debug("✅ applyTransform completed")
        #endif
    }

    // MARK: - Space Key Monitoring
    private func setupSpaceKeyMonitors() {
        #if DEBUG
        logger.debug("🔧 Setting up global and local space key monitors")
        #endif

        // Monitor key down events globally
        keyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 49 { // Space key
                self?.isSpaceKeyPressed = true
                self?.updateCursor() // カーソルを更新
                #if DEBUG
                self?.logger.debug("🔘 Global Space key pressed")
                #endif
            }
        }

        // Monitor key up events globally
        keyUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { [weak self] event in
            if event.keyCode == 49 { // Space key
                self?.isSpaceKeyPressed = false
                self?.isDragging = false
                self?.updateCursor() // カーソルを更新
                #if DEBUG
                self?.logger.debug("🔘 Global Space key released")
                #endif
            }
        }

        // Also monitor local events (when our app has focus)
        localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 49 { // Space key
                self?.isSpaceKeyPressed = true
                self?.updateCursor() // カーソルを更新
                #if DEBUG
                self?.logger.debug("🔘 Local Space key pressed")
                #endif
                // Return nil to consume the event and prevent it from propagating
                return nil
            }
            return event
        }

        localKeyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
            if event.keyCode == 49 { // Space key
                self?.isSpaceKeyPressed = false
                self?.isDragging = false
                self?.updateCursor() // カーソルを更新
                #if DEBUG
                self?.logger.debug("🔘 Local Space key released")
                #endif
                // Return nil to consume the event
                return nil
            }
            return event
        }
    }

    private func removeSpaceKeyMonitors() {
        if let monitor = keyDownMonitor {
            NSEvent.removeMonitor(monitor)
            keyDownMonitor = nil
        }
        if let monitor = keyUpMonitor {
            NSEvent.removeMonitor(monitor)
            keyUpMonitor = nil
        }
        if let monitor = localKeyDownMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyDownMonitor = nil
        }
        if let monitor = localKeyUpMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyUpMonitor = nil
        }
        #if DEBUG
        logger.debug("🗑️ Removed all space key monitors")
        #endif
    }

    deinit {
        // NotificationObserverを削除
        NotificationCenter.default.removeObserver(self)

        // キーモニターを削除
        removeSpaceKeyMonitors()
    }
}

// MARK: - Custom Window for Click-Through
@available(macOS 12.3, *)
class ClickThroughWindow: NSWindow {
    var isGlobalClickThroughEnabled = false

    // Logger for debug output
    private let logger = Logger(subsystem: "com.example.GlassView", category: "Window")

    override var canBecomeKey: Bool {
        // クリック無視が有効な場合は、キーウィンドウにならない
        return !isGlobalClickThroughEnabled
    }

    override var canBecomeMain: Bool {
        // クリック無視が有効な場合は、メインウィンドウにならない
        return !isGlobalClickThroughEnabled
    }

    override func sendEvent(_ event: NSEvent) {
        #if DEBUG
        // デバッグログ: ウィンドウレベルでのイベントを記録
        if event.type == .scrollWheel {
            logger.debug("🪟 ClickThroughWindow.sendEvent: scrollWheel event received")
            logger.debug("  - globalClickThrough enabled: \(self.isGlobalClickThroughEnabled)")
            logger.debug("  - event deltaY: \(event.scrollingDeltaY)")
        }
        #endif

        if isGlobalClickThroughEnabled {
            // クリック無視が有効な場合は、イベントを処理しない
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

// MARK: - Event Forwarding View
@available(macOS 12.3, *)
class EventForwardingView: NSView {
    weak var targetImageView: ClickThroughImageView?

    private let logger = Logger(subsystem: "com.example.GlassView", category: "EventForwarding")

    override var acceptsFirstResponder: Bool {
        return true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // このビューは常に透明で、イベントのみを処理
        return self
    }

    override func resetCursorRects() {
        super.resetCursorRects()

        // ターゲットImageViewのカーソル状態を反映
        if let imageView = targetImageView {
            if imageView.shouldShowPanCursor {
                if imageView.isPanDragging {
                    addCursorRect(bounds, cursor: .closedHand)
                } else {
                    addCursorRect(bounds, cursor: .openHand)
                }
            } else {
                addCursorRect(bounds, cursor: .arrow)
            }
        } else {
            addCursorRect(bounds, cursor: .arrow)
        }
    }

    private func updateCursor() {
        // カーソル矩形を再計算してカーソルを更新
        window?.invalidateCursorRects(for: self)
        discardCursorRects()
        resetCursorRects()
    }

    override func scrollWheel(with event: NSEvent) {
        #if DEBUG
        logger.debug("🔄 EventForwardingView.scrollWheel - forwarding to targetImageView")
        logger.debug("  - point in window: \(String(describing: event.locationInWindow))")
        logger.debug("  - deltaY: \(event.scrollingDeltaY)")
        #endif

        // ターゲットのImageViewに転送
        if let imageView = targetImageView {
            imageView.scrollWheel(with: event)
        } else {
            super.scrollWheel(with: event)
        }
    }

    override func mouseDown(with event: NSEvent) {
        #if DEBUG
        logger.debug("🔄 EventForwardingView.mouseDown - forwarding to targetImageView")
        #endif

        // ターゲットのImageViewに転送
        if let imageView = targetImageView {
            imageView.mouseDown(with: event)
        } else {
            super.mouseDown(with: event)
        }
    }

    override func mouseUp(with event: NSEvent) {
        #if DEBUG
        logger.debug("🔄 EventForwardingView.mouseUp - forwarding to targetImageView")
        #endif

        // ターゲットのImageViewに転送
        if let imageView = targetImageView {
            imageView.mouseUp(with: event)
        } else {
            super.mouseUp(with: event)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        #if DEBUG
        logger.debug("🔄 EventForwardingView.mouseDragged - forwarding to targetImageView")
        #endif

        // ターゲットのImageViewに転送
        if let imageView = targetImageView {
            imageView.mouseDragged(with: event)
        } else {
            super.mouseDragged(with: event)
        }
    }

    override func keyDown(with event: NSEvent) {
        #if DEBUG
        logger.debug("🔄 EventForwardingView.keyDown - forwarding to targetImageView")
        #endif

        // ターゲットのImageViewに転送
        if let imageView = targetImageView {
            imageView.keyDown(with: event)
        } else {
            super.keyDown(with: event)
        }
    }

    override func keyUp(with event: NSEvent) {
        #if DEBUG
        logger.debug("🔄 EventForwardingView.keyUp - forwarding to targetImageView")
        #endif

        // ターゲットのImageViewに転送
        if let imageView = targetImageView {
            imageView.keyUp(with: event)
        } else {
            super.keyUp(with: event)
        }
    }
}
