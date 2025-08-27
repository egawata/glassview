import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // アプリケーションが起動した時の処理
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // アプリケーションが終了する時の処理
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
