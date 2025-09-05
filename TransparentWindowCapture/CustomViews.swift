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

// MARK: - Custom Image View for Click-Through
@available(macOS 12.3, *)
class ClickThroughImageView: NSImageView {
    var isClickThroughEnabled = false

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
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if isClickThroughEnabled {
            // クリック透過が有効な場合は、このビューではヒットテストを行わない
            return nil
        }
        return super.hitTest(point)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        // クリック透過が有効な場合は、マウスクリックを受け入れない
        return !isClickThroughEnabled
    }

    override func mouseDown(with event: NSEvent) {
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

    func setClickThroughEnabled(_ enabled: Bool) {
        isClickThroughEnabled = enabled
        needsDisplay = true
    }

    // MARK: - Transform Methods
    func zoomIn() {
        let newScale = min(currentScale + scaleStep, maxScale)
        setScale(newScale)
    }

    func zoomOut() {
        let newScale = max(currentScale - scaleStep, minScale)
        setScale(newScale)
    }

    func setScale(_ scale: CGFloat) {
        currentScale = max(minScale, min(scale, maxScale))
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

    override var canBecomeKey: Bool {
        // クリック無視が有効な場合は、キーウィンドウにならない
        return !isGlobalClickThroughEnabled
    }

    override var canBecomeMain: Bool {
        // クリック無視が有効な場合は、メインウィンドウにならない
        return !isGlobalClickThroughEnabled
    }

    override func sendEvent(_ event: NSEvent) {
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
