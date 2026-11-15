import AppKit
import SwiftData
import SwiftUI

/// 菜单栏快捷入口（PRD 3.2）：最近连接的前 5 台，点一下直接连。
struct MenuBarQuickAccess: View {
    @Query private var allServers: [Server]
    @Environment(AppStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let recents = Self.recentServers(allServers, limit: 5)

        if recents.isEmpty {
            Button("打开 ShellCove") { openMainWindow() }
        } else {
            ForEach(recents) { server in
                Button("\(server.name) · \(server.hostLine)") {
                    connect(server)
                }
            }
        }

        Divider()
        Button("新增服务器…") {
            openMainWindow()
            store.editingServer = nil
            store.isEditorPresented = true
        }
        Button("设置…") {
            openMainWindow()
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
        Divider()
        Button("退出 ShellCove") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }

    // MARK: - 动作

    /// 打开主窗口并置于前台；openWindow 对已存在的窗口是聚焦复用。
    private func openMainWindow() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }

    private func connect(_ server: Server) {
        openMainWindow()
        store.openTerminal(server)
    }

    /// 最近连接的服务器：有连接记录的按时间倒序取前 n 台（纯函数，便于单测）。
    static func recentServers(_ servers: [Server], limit: Int = 5) -> [Server] {
        servers
            .compactMap { server -> (Date, Server)? in
                guard let date = server.lastConnectedAt else { return nil }
                return (date, server)
            }
            .sorted { $0.0 > $1.0 }
            .prefix(limit)
            .map(\.1)
    }
}
