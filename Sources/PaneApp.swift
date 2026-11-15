import AppKit
import ServiceManagement
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    static var openMainWindow: (() -> Void)?

    static func register(_ open: @escaping () -> Void) {
        openMainWindow = open
    }

    private var launchedAtLogin = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        Typeface.register()
        launchedAtLogin = Self.startedWithSession()
        if launchedAtLogin { NSApp.setActivationPolicy(.accessory) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        launchedAtLogin = launchedAtLogin || Self.launchedAsLoginItem()
        if launchedAtLogin {
            NSApp.setActivationPolicy(.accessory)
            DispatchQueue.main.async {
                Self.mainWindow?.orderOut(nil)
            }
        } else {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
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
        if !flag {
            if let window = Self.mainWindow {
                window.makeKeyAndOrderFront(nil)
            } else {
                AppDelegate.openMainWindow?()
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        return false
    }

    private static var mainWindow: NSWindow? {
        NSApp.windows.first { $0.identifier?.rawValue.hasPrefix("main") == true }
            ?? NSApp.windows.first { $0.canBecomeMain && $0.title == "Pane" }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private static func launchedAsLoginItem() -> Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventID == kAEOpenApplication,
              let property = event.paramDescriptor(forKeyword: keyAEPropData)
        else { return false }
        return property.enumCodeValue == keyAELaunchedAsLogInItem
    }

    private static func startedWithSession() -> Bool {
        guard SMAppService.mainApp.status == .enabled, let start = sessionStart() else { return false }
        return Date().timeIntervalSince(start) < 120
    }

    private static func sessionStart() -> Date? {
        let user = NSUserName()
        var latest: Date?
        setutxent()
        defer { endutxent() }
        while let record = getutxent() {
            var entry = record.pointee
            guard entry.ut_type == USER_PROCESS else { continue }
            let name = withUnsafeBytes(of: &entry.ut_user) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
            let line = withUnsafeBytes(of: &entry.ut_line) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
            guard name == user, line == "console" else { continue }
            let date = Date(timeIntervalSince1970: TimeInterval(entry.ut_tv.tv_sec) + TimeInterval(entry.ut_tv.tv_usec) / 1_000_000)
            if latest.map({ date > $0 }) ?? true { latest = date }
        }
        return latest
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
            CommandGroup(replacing: .appInfo) {
                Button("Sobre o Pane") {
                    NSApp.orderFrontStandardAboutPanel(nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
            CommandGroup(replacing: .appSettings) {}
            CommandGroup(replacing: .systemServices) {
                OpenSettingsButton()
            }
            CommandGroup(before: .windowList) {
                ShowMainWindowButton()
            }
            CommandGroup(after: .newItem) {
                Button("Papel de parede aleatório") {
                    Task { await model.applyRandom() }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }

        Window("Configurações", id: "settings") {
            SettingsView()
                .environment(model)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

struct ShowMainWindowButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let _ = AppDelegate.register { [openWindow] in openWindow(id: "main") }
        Button("Mostrar o Pane") {
            NSApp.setActivationPolicy(.regular)
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut("0", modifiers: .command)
    }
}

struct OpenSettingsButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Configurações") {
            NSApp.setActivationPolicy(.regular)
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",", modifiers: .command)
    }
}
