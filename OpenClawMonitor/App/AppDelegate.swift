import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep app alive in menu bar when main window is closed
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // App is alive in both Dock and Menu Bar
    }
}
