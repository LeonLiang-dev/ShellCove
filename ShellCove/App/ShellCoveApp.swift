import SwiftData
import SwiftUI

@main
struct ShellCoveApp: App {
    @State private var store = AppStore()
    @State private var settings = SettingsStore()
    private let container: ModelContainer

    init() {
        do {
            container = try Persistence.makeContainer()
        } catch {
            fatalError("无法打开本地数据库：\(error)")
        }
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            MainWindow()
                .environment(store)
                .environment(settings)
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

        // ⌘, 由系统自动挂到「设置…」菜单项（PRD FR-07）。
        Settings {
            SettingsView()
                .environment(store)
                .environment(settings)
                .modelContainer(container)
        }

        // 菜单栏快捷入口（PRD 3.2）：最近连接的前 5 台。
        MenuBarExtra("ShellCove", systemImage: "terminal.fill") {
            MenuBarQuickAccess()
                .environment(store)
                .modelContainer(container)
        }
        .menuBarExtraStyle(.menu)
    }
}
