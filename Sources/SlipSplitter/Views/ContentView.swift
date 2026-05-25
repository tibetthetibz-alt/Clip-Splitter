import SwiftUI

struct ContentView: View {
    @Bindable var store: ProcessingStore

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store)
        } detail: {
            DetailView(store: store)
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    store.chooseInputFolder()
                } label: {
                    Label("Input", systemImage: "tray.and.arrow.down")
                }

                Button {
                    store.chooseOutputFolder()
                } label: {
                    Label("Output", systemImage: "folder.badge.gearshape")
                }

                Button {
                    Task { await store.process() }
                } label: {
                    Label("Run", systemImage: "play.fill")
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(!store.canProcess)
            }
        }
    }
}
