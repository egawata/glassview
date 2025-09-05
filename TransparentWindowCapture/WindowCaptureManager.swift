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

// MARK: - WindowCaptureManager Protocol
protocol WindowCaptureManagerDelegate: AnyObject {
    func didReceiveNewFrame(_ image: NSImage)
    func didEncounterError(_ error: Error)
}

// MARK: - WindowCaptureManager
@available(macOS 12.3, *)
class WindowCaptureManager: NSObject, @unchecked Sendable {
    weak var delegate: WindowCaptureManagerDelegate?

    private var captureTimer: Timer?
    private var selectedWindow: SCWindow?

    func startCapture(for window: SCWindow, frameRate: Double = 30.0) {
        selectedWindow = window

        // タイマーでキャプチャを開始（指定されたフレームレート）
        let interval = 1.0 / frameRate
        captureTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            self.captureFrame()
        }
    }

    func stopCapture() {
        captureTimer?.invalidate()
        captureTimer = nil
        selectedWindow = nil
    }

    func updateFrameRate(_ frameRate: Double) {
        guard selectedWindow != nil else { return }

        // 現在のキャプチャを停止
        captureTimer?.invalidate()

        // 新しいフレームレートでキャプチャを再開
        let interval = 1.0 / frameRate
        captureTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            self.captureFrame()
        }
    }

    private func captureFrame() {
        guard let window = selectedWindow else { return }

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
