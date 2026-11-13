import SwiftData
import SwiftUI

struct MainWindow: View {
    @Environment(AppStore.self) private var store
    @Environment(\.modelContext) private var context

    @Query(sort: \Server.createdAt) private var servers: [Server]
    @Query(sort: \ServerGroup.sortIndex) private var groups: [ServerGroup]

    var body: some View {
        @Bindable var store = store

        VStack(spacing: 0) {
            TitleBar()
            Rectangle().fill(Theme.hairline).frame(height: 1)

            HStack(spacing: 0) {
                LeftColumn(
                    allServers: servers,
                    visibleServers: filteredServers,
                    groups: groups,
                    tags: tagCounts
                )
                .frame(width: Theme.leftColumnWidth)

                Rectangle().fill(Theme.hairline).frame(width: 1)

                ZStack {
                    DetailPane(
                        server: selectedServer,
                        hasAnyServer: !servers.isEmpty
                    )

                    if let terminalServer = store.terminalServer {
                        TerminalPane(server: terminalServer)
                            .transition(
                                .asymmetric(
                                    insertion: .opacity
                                        .combined(with: .offset(y: 10))
                                        .combined(with: .scale(scale: 0.995)),
                                    removal: .opacity
                                )
                            )
                            .zIndex(1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // 与原型一致：从下方轻微上浮并淡入（PRD FR-05）。
                .animation(
                    .timingCurve(0.22, 1, 0.36, 1, duration: 0.32),
                    value: store.terminalServer?.id
                )
            }
        }
        .overlay {
            if store.isPalettePresented {
                CommandPalette(servers: servers)
                    .zIndex(10)
            }
        }
        .overlay(alignment: .bottom) {
            ToastView(text: store.toast)
                .padding(.bottom, 22)
                .animation(.easeOut(duration: 0.2), value: store.toast)
                .allowsHitTesting(false)
                .zIndex(20)
        }
        .animation(.easeOut(duration: 0.16), value: store.isPalettePresented)
        .task {
            store.bootstrap(context: context)
        }
        .sheet(isPresented: $store.isEditorPresented) {
            ServerEditor(server: store.editingServer)
        }
    }

    // MARK: - 过滤与选中

    private var filteredServers: [Server] {
        let query = store.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return servers.filter { server in
            matchesSearch(server, query: query)
                && matchesGroup(server)
                && matchesTag(server)
                && matchesQuickFilter(server)
        }
    }

    private var selectedServer: Server? {
        if let id = store.selectedServerID,
           let match = servers.first(where: { $0.id == id }) {
            return match
        }
        return filteredServers.first
    }

    /// 标签及其使用次数，只显示仍在使用的标签。
    private var tagCounts: [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for server in servers {
            for tag in server.tags {
                counts[tag.name, default: 0] += 1
            }
        }
        return counts
            .filter { $0.value > 0 }
            .sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
            .map { (name: $0.key, count: $0.value) }
    }

    private func matchesSearch(_ server: Server, query: String) -> Bool {
        guard !query.isEmpty else { return true }
        let haystack = [
            server.name,
            server.host,
            server.domain,
            server.username,
            server.owner,
            server.region,
            server.tags.map(\.name).joined(separator: " ")
        ].joined(separator: " ").lowercased()
        return haystack.contains(query)
    }

    private func matchesGroup(_ server: Server) -> Bool {
        switch store.groupSelection {
        case .all:
            true
        case .group(let id):
            server.group?.id == id
        case .ungrouped:
            server.group == nil
        }
    }

    private func matchesTag(_ server: Server) -> Bool {
        guard let tagFilter = store.tagFilter else { return true }
        return server.tags.contains { $0.name == tagFilter }
    }

    private func matchesQuickFilter(_ server: Server) -> Bool {
        switch store.quickFilter {
        case .all:
            true
        case .recent:
            server.lastConnectedAt != nil
        }
    }
}
