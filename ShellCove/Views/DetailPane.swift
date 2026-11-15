import AppKit
import SwiftData
import SwiftUI

struct DetailPane: View {
    let server: Server?
    let hasAnyServer: Bool

    var body: some View {
        if let server {
            ServerDetail(server: server)
                .id(server.id)
        } else {
            EmptyDetail(hasAnyServer: hasAnyServer)
        }
    }
}

// MARK: - 详情

private struct ServerDetail: View {
    let server: Server

    @Environment(AppStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(\.modelContext) private var context

    @State private var showDeleteConfirm = false
    @State private var showAllRecords = false
    @State private var isProbing = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Theme.hairline).frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    metaStrip
                    notesCard
                    infoCard
                    sessionsCard
                    deleteButton
                    Color.clear.frame(height: 10)
                }
                .padding(.horizontal, 28)
                .padding(.top, 16)
            }
        }
        .alert("删除 \(server.name)？", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) { deleteServer() }
        } message: {
            Text("该服务器的连接记录将一并删除，且无法恢复。")
        }
        .sheet(isPresented: $showAllRecords) {
            SessionRecordsSheet(server: server)
        }
        // 终端覆盖右栏时，不让底层详情页的快捷键抢焦点。
        .disabled(store.terminalServer != nil)
        // 打开详情时自动探活（PRD FR-07，默认关闭）；切换服务器时 task 重新触发。
        .task(id: server.id) {
            guard settings.autoProbeOnDetailOpen else { return }
            await probe()
        }
    }

    // MARK: 头部

    private var header: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    EnvPill(environment: server.environment)
                    Text("上次连接 \(lastConnectedText)")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 9) {
                    Text(server.name)
                        .font(.system(size: 22, weight: .semibold))
                        .tracking(-0.35)
                        .lineLimit(1)
                    StatusDot(state: server.connectionState, size: 7)
                }

                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Button(server.username) {
                            copyText(server.username, toast: "已复制登录用户")
                        }
                        .buttonStyle(.plain)
                        .help("点击复制登录用户")

                        Text("@")

                        Button(server.host) {
                            copyText(server.host, toast: "已复制主机地址")
                        }
                        .buttonStyle(.plain)
                        .help("点击复制主机地址")
                    }
                    SepDot()
                    Text("port \(server.port)")
                    SepDot()
                    Text(server.osVersion.isEmpty ? "系统未知" : server.osVersion)
                }
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                Button {
                    store.openTerminal(server)
                } label: {
                    Label("连接", systemImage: "terminal")
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .keyboardShortcut(.return, modifiers: .command)
                .help("在右侧打开终端 (⌘⏎)")

                Button {
                    copyCommand()
                } label: {
                    Label("复制", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .keyboardShortcut("c", modifiers: [.command, .option])
                .help("复制 ssh 命令 (⌘⌥C)")

                Button {
                    edit()
                } label: {
                    Label("编辑", systemImage: "square.and.pencil")
                }
                .buttonStyle(.bordered)
                .keyboardShortcut("e", modifiers: .command)
                .help("编辑服务器 (⌘E)")

                Menu {
                    Button("复制主机地址") {
                        copyText(server.host, toast: "已复制主机地址")
                    }
                    Button("复制登录用户") {
                        copyText(server.username, toast: "已复制登录用户")
                    }
                    if let key = server.privateKeyPath, !key.isEmpty {
                        Button("复制私钥路径") {
                            copyText(key, toast: "已复制私钥路径")
                        }
                    }
                    Divider()
                    Button("删除服务器", role: .destructive) {
                        showDeleteConfirm = true
                    }
                } label: {
                    Label("更多", systemImage: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .controlSize(.regular)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
    }

    // MARK: 状态条

    private var metaStrip: some View {
        HStack(spacing: 0) {
            metaItem(title: "状态") {
                HStack(spacing: 6) {
                    StatusDot(state: server.connectionState)
                    Text(server.connectionState.label)
                        .font(.system(size: 12.8, weight: .medium))
                        .foregroundStyle(
                            server.connectionState == .unknown ? Color.secondary : Color.primary
                        )
                }
            }

            metaDivider

            metaItem(title: "延时") {
                Text(server.latencyText)
                    .font(.system(size: 12.8, weight: .medium))
                    .foregroundStyle(
                        server.lastProbeAt != nil && server.lastLatencyMs == nil
                            ? Theme.production
                            : Color.secondary
                    )
            }

            metaDivider

            metaItem(title: "认证") {
                Text(server.authMode.displayName)
                    .font(.system(size: 12.8, weight: .medium))
                    .lineLimit(1)
            }

            metaDivider

            metaItem(title: "负责人") {
                Text(server.owner.isEmpty ? "未指定" : server.owner)
                    .font(.system(size: 12.8, weight: .medium))
                    .foregroundStyle(server.owner.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button {
                Task { await probe() }
            } label: {
                if isProbing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("检测", systemImage: "waveform.path.ecg")
                        .font(.system(size: 11.5))
                }
            }
            .buttonStyle(.borderless)
            .disabled(isProbing)
            .help("手动检测一次连通性与时延")
            .padding(.trailing, 14)
        }
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12).fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.hairline)
        )
    }

    private func metaItem<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            content()
        }
        .padding(.horizontal, 16)
    }

    private var metaDivider: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(width: 1, height: 26)
    }

    // MARK: 作用与说明

    private var notesCard: some View {
        DetailCard(
            title: "作用与说明",
            icon: "doc.text",
            actionTitle: "编辑",
            action: edit
        ) {
            if server.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    Text("写清楚这台机器的作用、能不能重启、日志在哪。")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                    Button("添加说明", action: edit)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                MarkdownView(text: server.notes)
            }
        }
    }

    // MARK: 基础信息

    private var infoCard: some View {
        DetailCard(title: "基础信息", icon: "info.circle") {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), alignment: .topLeading), count: 3),
                alignment: .leading,
                spacing: 14
            ) {
                infoItem("主机地址", server.host, monospaced: true)
                infoItem("域名", server.domain.isEmpty ? "—" : server.domain, monospaced: true)
                infoItem("端口 / 用户", "\(server.port) · \(server.username)", monospaced: true)
                infoItem("分组", server.group?.name ?? "未分组")
                infoItem("负责人", server.owner.isEmpty ? "未指定" : server.owner)
                infoItem("所在地域", server.region.isEmpty ? "—" : server.region)
                infoItem("系统版本", server.osVersion.isEmpty ? "—" : server.osVersion)
                infoItem("到期时间", expiryText, warning: isExpired)
                infoItem("最近连接", lastConnectedText)
            }

            if !server.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(server.tags) { tag in
                        Text("#\(tag.name)")
                            .font(.system(size: 10.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2.5)
                            .background(
                                RoundedRectangle(cornerRadius: 6).fill(Theme.surfaceStrong)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.hairline)
                            )
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.top, 14)
            }

            if let key = server.privateKeyPath, !key.isEmpty {
                HStack(spacing: 6) {
                    Text("私钥")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Text(key)
                        .font(.system(size: 10.8, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                }
                .padding(.top, 10)
            }
        }
    }

    private func infoItem(
        _ key: String,
        _ value: String,
        monospaced: Bool = false,
        warning: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(key)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Text(warning ? "\(value) · 已到期" : value)
                .font(.system(size: monospaced ? 11.2 : 12.2, design: monospaced ? .monospaced : .default))
                .foregroundStyle(warning ? Theme.staging : Color.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    // MARK: 最近连接

    private var sessionsCard: some View {
        let recent = server.sessions
            .sorted { $0.startedAt > $1.startedAt }
            .prefix(4)

        return DetailCard(
            title: "最近连接",
            icon: "clock",
            actionTitle: "全部记录",
            action: { showAllRecords = true }
        ) {
            if recent.isEmpty {
                Text("还没有连接记录。连接服务器后会自动记录时间与时长。")
                    .font(.system(size: 12.2))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recent.enumerated()), id: \.element.id) { index, session in
                        HStack(spacing: 10) {
                            IconTile(systemName: "terminal", size: 20)
                            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 11.8))
                            Text(durationText(session))
                                .font(.system(size: 10.4, design: .monospaced))
                                .foregroundStyle(.tertiary)
                            Spacer()
                            if let code = session.exitCode {
                                Text("exit \(code)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(
                                        code == 0
                                            ? Theme.success
                                            : Theme.production
                                    )
                            }
                        }
                        .padding(.vertical, 7)

                        if index < recent.count - 1 {
                            Rectangle().fill(Theme.hairline).frame(height: 1)
                        }
                    }
                }
            }
        }
    }

    private var deleteButton: some View {
        HStack {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("删除服务器", systemImage: "trash")
                    .font(.system(size: 11.5))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.production.opacity(0.85))
            Spacer()
        }
        .padding(.top, 4)
    }

    // MARK: 辅助

    private var lastConnectedText: String {
        guard let date = server.lastConnectedAt else { return "从未" }
        return date.formatted(.relative(presentation: .named))
    }

    private var expiryText: String {
        guard let date = server.expiryDate else { return "—" }
        return date.formatted(date: .numeric, time: .omitted)
    }

    private var isExpired: Bool {
        guard let date = server.expiryDate else { return false }
        return date < Calendar.current.startOfDay(for: Date())
    }

    private func durationText(_ session: SessionRecord) -> String {
        guard let seconds = session.durationSeconds else { return "—" }
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        let rest = seconds % 60
        return rest == 0 ? "\(minutes)m" : "\(minutes)m \(rest)s"
    }

    private func edit() {
        store.editingServer = server
        store.isEditorPresented = true
    }

    private func deleteServer() {
        let name = server.name
        KeychainService.delete(account: server.id.uuidString)
        store.selectedServerID = nil
        store.preventsAutoSelection = true
        context.delete(server)
        try? context.save()
        store.showToast("已删除 \(name)")
    }

    private func copyCommand() {
        copyText(server.sshCommand, toast: "已复制 ssh 命令")
    }

    private func copyText(_ text: String, toast: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        store.showToast(toast)
    }

    private func probe() async {
        guard !isProbing else { return }
        isProbing = true
        let latency = await ConnectionProbe.latency(host: server.host, port: server.port)
        server.lastProbeAt = Date()
        server.lastLatencyMs = latency
        try? context.save()
        isProbing = false

        if let latency {
            store.showToast("已连通 · \(latency) ms")
        } else {
            store.showToast("无法连接到 \(server.host):\(server.port)")
        }
    }
}

// MARK: - 全部连接记录

private struct SessionRecordsSheet: View {
    let server: Server

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SessionRecord.startedAt, order: .reverse)
    private var records: [SessionRecord]

    private var serverRecords: [SessionRecord] {
        records.filter { $0.server?.id == server.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("连接记录")
                        .font(.system(size: 15, weight: .semibold))
                    Text("\(server.name) · \(serverRecords.count) 条")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("完成") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(18)

            Rectangle().fill(Theme.hairline).frame(height: 1)

            if serverRecords.isEmpty {
                ContentUnavailableView(
                    "还没有连接记录",
                    systemImage: "clock",
                    description: Text("连接服务器后，这里会按时间倒序列出全部记录。")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(serverRecords, id: \.id) { record in
                            recordRow(record)
                            Rectangle()
                                .fill(Theme.hairline)
                                .frame(height: 1)
                                .padding(.leading, 52)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .frame(width: 560, height: 520)
    }

    private func recordRow(_ record: SessionRecord) -> some View {
        HStack(spacing: 12) {
            IconTile(systemName: "terminal", size: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(record.startedAt.formatted(date: .abbreviated, time: .standard))
                    .font(.system(size: 12))
                Text(record.endReason.displayName)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 8)

            Text(durationText(record))
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(.secondary)

            if let code = record.exitCode {
                Text("exit \(code)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(
                        code == 0
                            ? Theme.success
                            : Theme.production
                    )
            } else {
                Text("exit —")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
    }

    private func durationText(_ record: SessionRecord) -> String {
        guard let seconds = record.durationSeconds else { return "—" }
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        let rest = seconds % 60
        return rest == 0 ? "\(minutes)m" : "\(minutes)m \(rest)s"
    }
}

// MARK: - 空状态

private struct EmptyDetail: View {
    let hasAnyServer: Bool

    @Environment(AppStore.self) private var store

    private var isAwaitingSelection: Bool {
        hasAnyServer && store.preventsAutoSelection && store.selectedServerID == nil
    }

    var body: some View {
        ContentUnavailableView {
            if hasAnyServer {
                Label(title, systemImage: icon)
            } else {
                VStack(spacing: 14) {
                    BrandMark(size: 56)
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                }
            }
        } description: {
            if isAwaitingSelection {
                Text("从左侧列表选择一台机器，查看用途、状态与最近连接。")
            } else if hasAnyServer {
                if store.quickFilter == .online {
                    Text("还没有探活结果。打开服务器详情，点「检测」获取状态。")
                } else {
                    Text("换一个分组或标签，或者清空搜索条件再看看。")
                }
            } else {
                Text("添加第一台服务器，写清它的用途，之后一键连上去。")
            }
        } actions: {
            if isAwaitingSelection {
                EmptyView()
            } else if hasAnyServer {
                Button("清除筛选") {
                    store.clearFilters()
                }
            } else {
                Button("新增服务器") {
                    store.editingServer = nil
                    store.isEditorPresented = true
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)

                // PRD 8.3：空状态提供「新增」与「从 SSH 配置导入」两个入口。
                Button("从 SSH 配置导入") {
                    store.isSSHImportPresented = true
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var title: String {
        if isAwaitingSelection { return "选择一台服务器" }
        return hasAnyServer ? "没有匹配的服务器" : "还没有服务器"
    }

    private var icon: String {
        if isAwaitingSelection { return "sidebar.left" }
        return hasAnyServer ? "line.3.horizontal.decrease.circle" : "server.rack"
    }
}

// MARK: - 卡片容器

private struct DetailCard<Content: View>: View {
    let title: String
    let icon: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 10.8, weight: .semibold))
                    .tracking(0.4)
                Spacer()
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(.plain)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.accent)
                }
            }
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 15)
            .padding(.vertical, 11)

            Rectangle().fill(Theme.hairline).frame(height: 1)

            content
                .padding(15)
        }
        .background(
            RoundedRectangle(cornerRadius: 12).fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.hairline)
        )
    }
}

private struct SepDot: View {
    var body: some View {
        Circle()
            .fill(Color.secondary.opacity(0.5))
            .frame(width: 3, height: 3)
    }
}
