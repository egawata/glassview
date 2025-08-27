import Foundation
import ScreenCaptureKit
import AppKit

protocol WindowCaptureManagerDelegate: AnyObject {
    func didReceiveNewFrame(_ image: NSImage)
    func didEncounterError(_ error: Error)
}

@available(macOS 12.3, *)
class WindowCaptureManager: NSObject, SCStreamDelegate, SCStreamOutput {
    weak var delegate: WindowCaptureManagerDelegate?
    
    private var stream: SCStream?
    private var streamConfiguration: SCStreamConfiguration?
    
    func startCapture(for window: SCWindow) {
        Task {
            do {
                // ストリーム設定を作成
                let configuration = SCStreamConfiguration()
                configuration.width = Int(window.frame.width)
                configuration.height = Int(window.frame.height)
                configuration.pixelFormat = kCVPixelFormatType_32BGRA
                configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30) // 30 FPS
                configuration.queueDepth = 3
                
                // フィルターを作成（選択されたウィンドウのみ）
                let filter = SCContentFilter(window: window)
                
                // ストリームを作成
                stream = SCStream(filter: filter, configuration: configuration, delegate: self)
                
                // 出力を追加
                try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: DispatchQueue.global(qos: .userInteractive))
                
                // ストリーミング開始
                try await stream?.startCapture()
                
                streamConfiguration = configuration
                
            } catch {
                delegate?.didEncounterError(error)
            }
        }
    }
    
    func stopCapture() {
        Task {
            do {
                try await stream?.stopCapture()
                stream = nil
                streamConfiguration = nil
            } catch {
                delegate?.didEncounterError(error)
            }
        }
    }
    
    // MARK: - SCStreamOutput
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        // CVPixelBufferからNSImageに変換
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return
        }
        
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        
        // メインスレッドでデリゲートに通知
        DispatchQueue.main.async {
            self.delegate?.didReceiveNewFrame(nsImage)
        }
    }
    
    // MARK: - SCStreamDelegate
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        delegate?.didEncounterError(error)
    }
}
