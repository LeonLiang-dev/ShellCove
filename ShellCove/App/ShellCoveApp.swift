import SwiftData
import SwiftUI

@main
struct ShellCoveApp: App {
    @State private var store = AppStore()
    private let container: ModelContainer

    init() {
        do {
            container = try Persistence.makeContainer()
        } catch {
            fatalError("无法打开本地数据库：\(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainWindow()
                .environment(store)
                .modelContainer(container)
                .containerBackground(.thickMaterial, for: .window)
                .frame(minWidth: 940, minHeight: 620)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新增服务器…") {
                    store.editingServer = nil
                    store.isEditorPresented = true
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                Button("搜索服务器") {
                    store.isPalettePresented.toggle()
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }
    }
}
