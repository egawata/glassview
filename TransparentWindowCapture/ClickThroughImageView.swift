import Cocoa

class ClickThroughImageView: NSImageView {
    var isClickThroughEnabled = false
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        if isClickThroughEnabled {
            // クリック透過が有効な場合は、このビューではヒットテストを行わない
            return nil
        }
        return super.hitTest(point)
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        // マウスクリックを最初から受け入れる
        return !isClickThroughEnabled
    }
    
    func setClickThroughEnabled(_ enabled: Bool) {
        isClickThroughEnabled = enabled
        
        // ビューの更新を強制
        needsDisplay = true
    }
}
