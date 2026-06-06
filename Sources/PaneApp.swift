import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    static var openMainWindow: (() -> Void)?

    func applicationWillFinishLaunching(_ notification: Notification) {
        Typeface.register()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { _ in
            DispatchQueue.main.async {
                let open = NSApp.windows.contains { $0.isVisible && $0.canBecomeMain }
                if !open { NSApp.setActivationPolicy(.accessory) }
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.setActivationPolicy(.regular)
        if !flag { AppDelegate.openMainWindow?() }
        NSApp.activate(ignoringOtherApps: true)
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct PaneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel()

    var body: some Scene {
        Window("Pane", id: "main") {
            ContentView()
                .environment(model)
                .frame(minWidth: 980, minHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1240, height: 860)
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("Fechar e continuar em segundo plano") {
                    for window in NSApp.windows where window.isVisible && window.canBecomeMain {
                        window.close()
                    }
                }
                .keyboardShortcut("q", modifiers: .command)
                Button("Sair do Pane") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: [.command, .option])
            }
            CommandGroup(after: .newItem) {
                Button("Papel de parede aleatório") {
                    Task { await model.applyRandom() }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}
