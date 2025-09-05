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

        #if DEBUG
        // デバッグログ: セットアップ情報を記録
        logger.debug("🎯 ClickThroughImageView setup completed")
        logger.debug("  - frame: \(String(describing: self.frame))")
        logger.debug("  - bounds: \(String(describing: self.bounds))")
        logger.debug("  - wantsLayer: \(self.wantsLayer)")
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

    override func mouseDown(with event: NSEvent) {
        #if DEBUG
        // デバッグログ: mouseDownメソッドが呼ばれたことを記録
        logger.debug("🖱️ mouseDown called on ClickThroughImageView")
        logger.debug("  - clickThrough enabled: \(self.isClickThroughEnabled)")
        #endif

        if !isClickThroughEnabled {
            super.mouseDown(with: event)
        }
        // クリック透過が有効な場合は何もしない
    }

    override func mouseUp(with event: NSEvent) {
        if !isClickThroughEnabled {
            super.mouseUp(with: event)
        }
        // クリック透過が有効な場合は何もしない
    }

    override func mouseDragged(with event: NSEvent) {
        if !isClickThroughEnabled {
            super.mouseDragged(with: event)
        }
        // クリック透過が有効な場合は何もしない
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
        let newScale = min(currentScale + stepToUse, maxScale)
        #if DEBUG
        logger.debug("🔍 zoomIn: \(self.currentScale) → \(newScale) (step: \(stepToUse))")
        #endif
        setScale(newScale)
    }

    func zoomOut(step: CGFloat? = nil) {
        let stepToUse = step ?? scaleStep
        let newScale = max(currentScale - stepToUse, minScale)
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
        applyTransform()
    }

    func getCurrentScale() -> CGFloat {
        return currentScale
    }

    private func applyTransform() {
        guard let layer = layer else { return }

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.2)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))

        let transform = CATransform3DMakeScale(currentScale, currentScale, 1.0)
        layer.transform = transform

        CATransaction.commit()
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
