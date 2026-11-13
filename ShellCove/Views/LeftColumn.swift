import SwiftUI

struct LeftColumn: View {
    let allServers: [Server]
    let visibleServers: [Server]
    let groups: [ServerGroup]
    let tags: [(name: String, count: Int)]

    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            groupSection
            Rectangle().fill(Theme.hairline).frame(height: 1)
            serverSection
            Rectangle().fill(Theme.hairline).frame(height: 1)
            footer
        }
        .background(Theme.sidebar)
    }

    // MARK: - 分组与标签

    private var groupSection: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 6) {
                Text("分组")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.7)
                    .foregroundStyle(.tertiary)
                Spacer()
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.quaternary)
                    .help("在新增或编辑服务器时可以创建分组")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)

            GroupRow(
                title: "全部服务器",
                count: allServers.count,
                tint: nil,
                isSelected: store.groupSelection == .all && store.tagFilter == nil
            ) {
                store.selectGroup(.all)
            }

            ForEach(groups) { group in
                GroupRow(
                    title: group.name,
                    count: allServers.filter { $0.group?.id == group.id }.count,
                    tint: tint(for: group),
                    isSelected: store.groupSelection == .group(group.id)
                ) {
                    store.selectGroup(.group(group.id))
                }
            }

            let ungroupedCount = allServers.filter { $0.group == nil }.count
            if ungroupedCount > 0 {
                GroupRow(
                    title: "未分组",
                    count: ungroupedCount,
                    tint: Color.secondary.opacity(0.5),
                    isSelected: store.groupSelection == .ungrouped
                ) {
                    store.selectGroup(.ungrouped)
                }
            }

            if !tags.isEmpty {
                Text("标签")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.7)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 6)

                FlowLayout(spacing: 5, lineSpacing: 5) {
                    ForEach(tags, id: \.name) { tag in
                        TagFilterChip(
                            name: tag.name,
                            count: tag.count,
                            isSelected: store.tagFilter == tag.name
                        ) {
                            store.toggleTag(tag.name)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }

    private func tint(for group: ServerGroup) -> Color {
        ServerEnvironment.allCases
            .first { $0.defaultGroupName == group.name }?
            .tint ?? Theme.accent
    }

    // MARK: - 服务器列表

    private var serverSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(listTitle)
                    .font(.system(size: 12.6, weight: .semibold))
                    .lineLimit(1)
                Text("\(visibleServers.count)")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Theme.surface))
                Spacer()
                Button {
                    store.editingServer = nil
                    store.isEditorPresented = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 22, height: 22)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.surface))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.hairline)
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("新增服务器 (⌘N)")
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)

            HStack(spacing: 5) {
                ForEach(AppStore.QuickFilter.allCases) { filter in
                    FilterChip(
                        title: filter.title,
                        isSelected: store.quickFilter == filter
                    ) {
                        store.quickFilter = filter
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            if visibleServers.isEmpty {
                emptyList
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(visibleServers) { server in
                            ServerRow(
                                server: server,
                                isSelected: server.id == store.selectedServerID
                            ) {
                                store.select(server)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var listTitle: String {
        if let tagFilter = store.tagFilter {
            return "标签 · \(tagFilter)"
        }
        switch store.groupSelection {
        case .all:
            return "全部服务器"
        case .group(let id):
            return groups.first { $0.id == id }?.name ?? "分组"
        case .ungrouped:
            return "未分组"
        }
    }

    private var emptyList: some View {
        VStack(spacing: 9) {
            Image(systemName: allServers.isEmpty ? "server.rack" : "line.3.horizontal.decrease.circle")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.quaternary)
            Text(allServers.isEmpty ? "还没有服务器" : "没有匹配的服务器")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            if allServers.isEmpty {
                Button("新增服务器") {
                    store.editingServer = nil
                    store.isEditorPresented = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Button("清除筛选") {
                    store.clearFilters()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 24)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "internaldrive")
                .font(.system(size: 9.5))
            Text("本地存储 · SwiftData")
                .font(.system(size: 10))
            Spacer()
        }
        .foregroundStyle(.quaternary)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }
}

// MARK: - 行组件

private struct GroupRow: View {
    let title: String
    let count: Int
    let tint: Color?
    let isSelected: Bool
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if let tint {
                    Circle()
                        .fill(tint)
                        .frame(width: 7, height: 7)
                } else {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .frame(width: 7)
                }

                Text(title)
                    .font(.system(size: 12.6, weight: isSelected ? .medium : .regular))
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text("\(count)")
                    .font(.system(size: 10.5))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .frame(height: 29)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(background)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
        .onHover { hovered = $0 }
    }

    private var background: Color {
        if isSelected { return Theme.accent.opacity(0.14) }
        if hovered { return Theme.surface }
        return .clear
    }
}

private struct TagFilterChip: View {
    let name: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text("#\(name)")
                Text("\(count)")
                    .foregroundStyle(isSelected ? Theme.accent.opacity(0.8) : Color.secondary.opacity(0.5))
                    .monospacedDigit()
            }
            .font(.system(size: 10.8, weight: isSelected ? .medium : .regular))
            .padding(.horizontal, 8)
            .padding(.vertical, 2.5)
            .foregroundStyle(isSelected ? Theme.accent : Color.secondary)
            .background(
                Capsule().fill(isSelected ? Theme.accent.opacity(0.14) : Theme.surface)
            )
            .overlay(
                Capsule().strokeBorder(isSelected ? Theme.accent.opacity(0.28) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10.8, weight: isSelected ? .medium : .regular))
                .padding(.horizontal, 9)
                .padding(.vertical, 2.5)
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .background(
                    Capsule().fill(isSelected ? Theme.surfaceStrong : Theme.surface)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct ServerRow: View {
    let server: Server
    let isSelected: Bool
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                IconTile(systemName: iconName)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        StatusDot()
                        Text(server.name)
                            .font(.system(size: 12.6, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: 0)
                    }

                    Text(server.hostLine)
                        .font(.system(size: 10.4, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        EnvPill(environment: server.environment)
                        Spacer(minLength: 4)
                        Text(lastConnectedText)
                            .font(.system(size: 9.8))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(rowBackground)
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(server.environment.tint)
                        .frame(width: 3, height: 32)
                        .padding(.leading, 1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }

    private var rowBackground: Color {
        if isSelected { return Theme.surfaceStrong }
        if hovered { return Theme.surface }
        return .clear
    }

    private var iconName: String {
        let tagNames = server.tags.map(\.name)
        if tagNames.contains(where: { $0.contains("数据库") || $0.contains("缓存") }) {
            return "cylinder.split.1x2"
        }
        if tagNames.contains(where: { $0.contains("跳板") }) {
            return "shield.lefthalf.filled"
        }
        return "server.rack"
    }

    private var lastConnectedText: String {
        guard let date = server.lastConnectedAt else { return "从未连接" }
        return date.formatted(.relative(presentation: .named))
    }
}
