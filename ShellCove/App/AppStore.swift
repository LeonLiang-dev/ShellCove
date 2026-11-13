import Foundation
import Observation
import SwiftData

/// 界面状态集中在这里：选中项、过滤条件、搜索词、弹层与一次性提示。
/// 只保存 UI 状态，不持有 SwiftData 上下文。
@MainActor
@Observable
final class AppStore {
    enum GroupSelection: Hashable {
        case all
        case group(UUID)
        case ungrouped
    }

    enum QuickFilter: String, CaseIterable, Identifiable {
        case all
        case recent

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: "全部"
            case .recent: "最近连接"
            }
        }
    }

    var selectedServerID: UUID?
    var groupSelection: GroupSelection = .all
    /// 同一时刻只有分组或标签一个过滤条件生效（PRD FR-01）。
    var tagFilter: String?
    var quickFilter: QuickFilter = .all
    var searchText: String = ""

    var isEditorPresented = false
    /// 为空表示新增；有值表示编辑该服务器。
    var editingServer: Server?
    /// 非空时终端覆盖整个右栏（PRD FR-05）。
    var terminalServer: Server?
    var isPalettePresented = false
    var toast: String?

    private var didBootstrap = false
    private var toastTask: Task<Void, Never>?

    // MARK: - 初始化

    /// 首次启动时创建四个默认分组。只建分组，不建任何示例服务器（PRD 8.3）。
    func bootstrap(context: ModelContext) {
        guard !didBootstrap else { return }
        didBootstrap = true

        // 上次异常退出留下的未结束记录，标记为「异常结束」（PRD FR-06）。
        let unfinished = FetchDescriptor<SessionRecord>(
            predicate: #Predicate { $0.endedAt == nil }
        )
        if let records = try? context.fetch(unfinished), !records.isEmpty {
            for record in records {
                record.endedAt = record.startedAt
                record.durationSeconds = nil
                record.endReason = .interrupted
            }
            try? context.save()
        }

        var descriptor = FetchDescriptor<ServerGroup>()
        descriptor.fetchLimit = 1
        guard (try? context.fetch(descriptor))?.isEmpty ?? false else { return }

        let defaults: [(ServerEnvironment, Int)] = [
            (.production, 0),
            (.staging, 1),
            (.development, 2),
            (.infrastructure, 3)
        ]
        for (environment, index) in defaults {
            context.insert(
                ServerGroup(
                    name: environment.defaultGroupName,
                    sortIndex: index,
                    colorHex: environment.defaultColorHex
                )
            )
        }
        try? context.save()
    }

    /// 找到与环境对应的默认分组；找不到时返回 nil（服务器进入「未分组」）。
    func defaultGroup(for environment: ServerEnvironment, context: ModelContext) -> ServerGroup? {
        fetchGroup(named: environment.defaultGroupName, context: context)
    }

    func fetchGroup(named name: String, context: ModelContext) -> ServerGroup? {
        var descriptor = FetchDescriptor<ServerGroup>(
            predicate: #Predicate { $0.name == name }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// 新建分组；同名已存在时直接复用。
    @discardableResult
    func createGroup(named name: String, context: ModelContext) -> ServerGroup? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let existing = fetchGroup(named: trimmed, context: context) {
            return existing
        }
        let existingGroups = (try? context.fetch(FetchDescriptor<ServerGroup>())) ?? []
        let nextIndex = (existingGroups.map(\.sortIndex).max() ?? -1) + 1
        let group = ServerGroup(name: trimmed, sortIndex: nextIndex)
        context.insert(group)
        return group
    }

    // MARK: - 选择与过滤

    func select(_ server: Server) {
        // 切换服务器时结束当前终端，避免误连（PRD FR-05）。
        terminalServer = nil
        selectedServerID = server.id
    }

    func openTerminal(_ server: Server) {
        selectedServerID = server.id
        terminalServer = server
    }

    func closeTerminal() {
        terminalServer = nil
    }

    func selectGroup(_ selection: GroupSelection) {
        groupSelection = selection
        tagFilter = nil
    }

    func toggleTag(_ name: String) {
        if tagFilter == name {
            tagFilter = nil
        } else {
            tagFilter = name
            groupSelection = .all
        }
    }

    func clearFilters() {
        searchText = ""
        quickFilter = .all
        groupSelection = .all
        tagFilter = nil
    }

    // MARK: - 提示

    func showToast(_ text: String) {
        toast = text
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }
}

extension ServerEnvironment {
    /// 与 PRD 7.2 的环境色一致。
    var defaultColorHex: String {
        switch self {
        case .production: "#FF6B5E"
        case .staging: "#FFB340"
        case .development: "#58A6FF"
        case .infrastructure: "#A78BFA"
        }
    }
}
