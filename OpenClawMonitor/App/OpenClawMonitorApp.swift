import SwiftUI

@main
struct OpenClawMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup(id: "main") {
            MainWindow()
                .environmentObject(appViewModel)
                .preferredColorScheme(.dark)
                .frame(minWidth: 800, minHeight: 500)
                .task { appViewModel.loadData() }
        }
        .defaultSize(width: 1100, height: 720)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        MenuBarExtra("OpenClaw Monitor", image: "MenuBarIcon") {
            MenuBarPopover()
                .environmentObject(appViewModel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appViewModel)
                .preferredColorScheme(.dark)
        }
    }
}
