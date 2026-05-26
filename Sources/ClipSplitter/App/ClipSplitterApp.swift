import SwiftUI

@main
struct ClipSplitterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = ProcessingStore()

    var body: some Scene {
        WindowGroup("Clip Splitter", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 760, minHeight: 520)
        }
        Settings {
            SettingsView(store: store)
                .frame(width: 620, height: 460)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Process Videos") {
                    Task { await store.process() }
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(!store.canProcess)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let displayName =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Clip Splitter"
        NSApp.mainMenu?.items.first?.title = displayName
    }
}
