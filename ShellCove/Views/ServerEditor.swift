import AppKit
import SwiftData
import SwiftUI

/// 新增 / 编辑服务器。覆盖 PRD 7.1 的全部 P0 字段；
/// 凭据只记录私钥路径，应用不保存任何密码或私钥内容。
struct ServerEditor: View {
    let server: Server?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppStore.self) private var store

    @Query(sort: \ServerGroup.sortIndex) private var groups: [ServerGroup]
    @Query(sort: \Server.createdAt) private var allServers: [Server]

    @State private var name: String
    @State private var host: String
    @State private var domain: String
    @State private var port: String
    @State private var username: String
    @State private var environment: ServerEnvironment
    @State private var selectedGroupID: UUID?
    @State private var authMode: AuthMode
    @State private var password = ""
    @State private var hadStoredPassword = false
    @State private var privateKeyPath: String
    @State private var owner: String
    @State private var osVersion: String
    @State private var region: String
    @State private var notes: String
    @State private var tags: [String]
    @State private var tagInput = ""
    @State private var hasExpiry: Bool
    @State private var expiryDate: Date

    @State private var showNewGroupField = false
    @State private var newGroupName = ""
    @State private var createdGroup: ServerGroup?
    @State private var errorMessage: String?
    @State private var initialSnapshot: FormSnapshot?
    @State private var showDiscardAlert = false
    @State private var showWarningAlert = false
    @State private var warningMessage = ""

    @FocusState private var nameFocused: Bool

    init(server: Server?) {
        self.server = server
        _name = State(initialValue: server?.name ?? "")
        _host = State(initialValue: server?.host ?? "")
        _domain = State(initialValue: server?.domain ?? "")
        _port = State(initialValue: String(server?.port ?? 22))
        _username = State(initialValue: server?.username ?? NSUserName())
        _environment = State(initialValue: server?.environment ?? .development)
        _selectedGroupID = State(initialValue: server?.group?.id)
        _authMode = State(initialValue: server?.authMode ?? .keyAgent)
        _privateKeyPath = State(initialValue: server?.privateKeyPath ?? "")
        _owner = State(initialValue: server?.owner ?? "")
        _osVersion = State(initialValue: server?.osVersion ?? "")
        _region = State(initialValue: server?.region ?? "")
        _notes = State(initialValue: server?.notes ?? "")
        _tags = State(initialValue: server?.tags.map(\.name).sorted() ?? [])
        _hasExpiry = State(initialValue: server?.expiryDate != nil)
        _expiryDate = State(
            initialValue: server?.expiryDate
                ?? Calendar.current.date(byAdding: .year, value: 1, to: Date())
                ?? Date()
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Rectangle().fill(Theme.hairline).frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    connectionSection
                    profileSection
                    tagSection
                    notesSection
                }
                .padding(22)
            }

            Rectangle().fill(Theme.hairline).frame(height: 1)
            footer
        }
        .frame(width: 600, height: 700)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if server == nil, selectedGroupID == nil {
                selectedGroupID = store.defaultGroup(for: environment, context: context)?.id
            }
            if let server {
                hadStoredPassword = KeychainService.hasPassword(account: server.id.uuidString)
            }
            nameFocused = true
            if initialSnapshot == nil {
                initialSnapshot = currentSnapshot
            }
        }
        .interactiveDismissDisabled(hasUnsavedChanges)
        .alert("放弃修改？", isPresented: $showDiscardAlert) {
            Button("继续编辑", role: .cancel) {}
            Button("放弃修改", role: .destructive) { dismiss() }
        } message: {
            Text("当前填写的内容尚未保存。")
        }
    }

    // MARK: - 头部 / 底部

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(server == nil ? "新增服务器" : "编辑服务器")
                .font(.system(size: 16, weight: .semibold))
            Text("先记录它是什么，再决定怎么连。")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if let message = footerMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.production)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Button("取消") { cancel() }
                .keyboardShortcut(.cancelAction)

            Button(server == nil ? "保存" : "保存修改") { save() }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .alert("保存前确认", isPresented: $showWarningAlert) {
            Button("取消", role: .cancel) {}
            Button("仍然保存") { save(force: true) }
        } message: {
            Text(warningMessage)
        }
    }

    // MARK: - 连接

    private var connectionSection: some View {
        section("连接") {
            HStack(alignment: .top, spacing: 14) {
                Field(title: "名称", hint: "留空则使用主机地址") {
                    TextField("api-prod-01", text: $name)
                        .scField()
                        .focused($nameFocused)
                }
                Field(title: "主机地址") {
                    TextField("10.20.1.11 或 api.example.com", text: $host)
                        .scField()
                }
            }

            HStack(alignment: .top, spacing: 14) {
                Field(title: "域名", hint: "可选") {
                    TextField("api.example.com", text: $domain)
                        .scField()
                }
                Field(title: "端口") {
                    TextField("22", text: $port)
                        .scField()
                        .frame(width: 92)
                }
                Field(title: "登录用户") {
                    TextField("deploy", text: $username)
                        .scField()
                }
            }

            Field(title: "环境", hint: "决定列表色条与默认分组") {
                Picker("", selection: $environment) {
                    ForEach(ServerEnvironment.allCases) { env in
                        Text(env.displayName).tag(env)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Field(title: "分组") {
                HStack(spacing: 8) {
                    Picker("", selection: $selectedGroupID) {
                        Text("未分组").tag(UUID?.none)
                        ForEach(groups) { group in
                            Text(group.name).tag(Optional(group.id))
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 220)

                    Button {
                        showNewGroupField.toggle()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .semibold))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.bordered)
                    .help("新建分组")

                    Spacer()
                }

                if showNewGroupField {
                    HStack(spacing: 8) {
                        TextField("新分组名称", text: $newGroupName)
                            .scField()
                            .frame(maxWidth: 220)
                            .onSubmit(createGroup)
                        Button("创建", action: createGroup)
                            .buttonStyle(.bordered)
                            .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.top, 2)
                }
            }

            Field(title: "认证方式") {
                Picker("", selection: $authMode) {
                    ForEach(AuthMode.allCases) { mode in
                        Text(mode.shortName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 260)
            }

            if authMode == .keyAgent {
                Field(title: "私钥路径", hint: "留空则交给 ssh-agent / ~/.ssh/config") {
                    HStack(spacing: 8) {
                        TextField("~/.ssh/id_ed25519", text: $privateKeyPath)
                            .scField()
                        Button("选择…") { choosePrivateKey() }
                            .buttonStyle(.bordered)
                    }
                }
            } else {
                Field(
                    title: "登录密码",
                    hint: hadStoredPassword
                        ? "已保存到 Keychain，留空表示不修改"
                        : "保存到系统 Keychain，不写入数据库"
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        SecureField(hadStoredPassword ? "••••••••" : "输入密码", text: $password)
                            .scField()
                        Text("目标机器需要开启 PasswordAuthentication 才能用密码登录。")
                            .font(.system(size: 10))
                            .foregroundStyle(.quaternary)
                    }
                }
            }
        }
    }

    // MARK: - 资料

    private var profileSection: some View {
        section("资料") {
            HStack(alignment: .top, spacing: 14) {
                Field(title: "负责人", hint: "可选") {
                    TextField("张伟", text: $owner)
                        .scField()
                }
                Field(title: "系统版本", hint: "可选") {
                    TextField("Ubuntu 24.04", text: $osVersion)
                        .scField()
                }
            }

            HStack(alignment: .top, spacing: 14) {
                Field(title: "所在地域", hint: "可选") {
                    TextField("上海 · 阿里云", text: $region)
                        .scField()
                }
                Field(title: "到期时间") {
                    HStack(spacing: 8) {
                        Toggle("设置", isOn: $hasExpiry)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 11.5))
                        if hasExpiry {
                            DatePicker("", selection: $expiryDate, displayedComponents: .date)
                                .labelsHidden()
                                .datePickerStyle(.field)
                        }
                        Spacer()
                    }
                    .frame(height: 28)
                }
            }
        }
    }

    // MARK: - 标签

    private var tagSection: some View {
        section("标签") {
            if !tags.isEmpty {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text("#\(tag)")
                            Button {
                                tags.removeAll { $0 == tag }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 7.5, weight: .bold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.tertiary)
                        }
                        .font(.system(size: 10.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Theme.surfaceStrong))
                        .overlay(Capsule().strokeBorder(Theme.hairline))
                        .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("输入标签后回车，最多 8 个、每个 12 字", text: $tagInput)
                    .scField()
                    .onSubmit(addTag)
                Button("添加", action: addTag)
                    .buttonStyle(.bordered)
                    .disabled(!canAddTag)
            }
        }
    }

    // MARK: - 说明

    private var notesSection: some View {
        section("作用与说明") {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $notes)
                    .font(.system(size: 12.5))
                    .scrollContentBackground(.hidden)
                    .padding(7)

                if notes.isEmpty {
                    Text("这台机器跑什么？能不能重启？日志在哪？支持 Markdown。")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.quaternary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 15)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 140)
            .background(
                RoundedRectangle(cornerRadius: 8).fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.hairline)
            )
        }
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(.tertiary)
            content()
        }
    }

    // MARK: - 校验与保存

    private var isValid: Bool {
        guard !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let portValue = Int(port),
              (1...65535).contains(portValue),
              hostValidationMessage == nil else {
            return false
        }
        // 密码认证必须拿到密码：新建时必填，编辑时允许沿用已保存的密码。
        if authMode == .password, !hadStoredPassword, password.isEmpty {
            return false
        }
        return true
    }

    /// 主机只接受主机名或 IP，不允许空格、@ 与协议前缀（PRD FR-04）。
    private var hostValidationMessage: String? {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.contains(where: { $0.isWhitespace }) {
            return "主机地址不能包含空格"
        }
        if trimmed.contains("@") {
            return "主机地址不能包含 @"
        }
        if trimmed.contains("://") || trimmed.lowercased().hasPrefix("ssh:") {
            return "只填写主机名或 IP，不要带协议前缀"
        }
        return nil
    }

    private var portValidationMessage: String? {
        guard !port.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "端口不能为空"
        }
        guard let value = Int(port), (1...65535).contains(value) else {
            return "端口需要在 1–65535 之间"
        }
        return nil
    }

    private var footerMessage: String? {
        errorMessage ?? portValidationMessage ?? hostValidationMessage
    }

    private var currentSnapshot: FormSnapshot {
        FormSnapshot(
            name: name,
            host: host,
            domain: domain,
            port: port,
            username: username,
            environmentRaw: environment.rawValue,
            groupID: selectedGroupID,
            authModeRaw: authMode.rawValue,
            password: password,
            privateKeyPath: privateKeyPath,
            owner: owner,
            osVersion: osVersion,
            region: region,
            notes: notes,
            tags: tags,
            hasExpiry: hasExpiry,
            expiryDate: expiryDate
        )
    }

    private var hasUnsavedChanges: Bool {
        guard let initialSnapshot else { return false }
        return currentSnapshot != initialSnapshot
    }

    private func cancel() {
        if hasUnsavedChanges {
            showDiscardAlert = true
        } else {
            dismiss()
        }
    }

    private var canAddTag: Bool {
        let trimmed = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 12 && tags.count < 8 && !tags.contains(trimmed)
    }

    private func addTag() {
        guard canAddTag else {
            tagInput = ""
            return
        }
        let trimmed = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        tags.append(trimmed)
        tagInput = ""
    }

    private func createGroup() {
        guard let group = store.createGroup(named: newGroupName, context: context) else { return }
        try? context.save()
        createdGroup = group
        selectedGroupID = group.id
        newGroupName = ""
        showNewGroupField = false
    }

    private func choosePrivateKey() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".ssh", isDirectory: true)
        panel.message = "选择私钥文件（不会被复制）"

        if panel.runModal() == .OK, let url = panel.url {
            privateKeyPath = url.path
        }
    }

    private func save(force: Bool = false) {
        errorMessage = nil
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let portValue = Int(port), (1...65535).contains(portValue) else {
            errorMessage = "端口需要在 1–65535 之间"
            return
        }
        guard !trimmedHost.isEmpty, !trimmedUser.isEmpty else {
            errorMessage = "主机地址与登录用户不能为空"
            return
        }
        if let hostValidationMessage {
            errorMessage = hostValidationMessage
            return
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmedName.isEmpty ? trimmedHost : trimmedName
        let trimmedKey = privateKeyPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let keyPath: String? = authMode == .keyAgent && !trimmedKey.isEmpty ? trimmedKey : nil

        // 私钥缺失与重名都只警告，不阻断保存（PRD FR-04）。
        if !force {
            let warnings = saveWarnings(finalName: finalName, keyPath: keyPath)
            if !warnings.isEmpty {
                warningMessage = warnings.joined(separator: "\n")
                showWarningAlert = true
                return
            }
        }

        let group = resolveSelectedGroup()
        let resolvedTags = resolveTags()

        let target: Server
        if let existing = server {
            target = existing
        } else {
            target = Server(name: finalName, host: trimmedHost, username: trimmedUser)
            context.insert(target)
        }

        let connectionChanged = target.host != trimmedHost || target.port != portValue

        target.name = finalName
        target.host = trimmedHost
        target.domain = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        target.port = portValue
        target.username = trimmedUser
        target.environment = environment
        target.authMode = authMode
        target.privateKeyPath = keyPath
        target.group = group
        target.owner = owner.trimmingCharacters(in: .whitespacesAndNewlines)
        target.osVersion = osVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        target.region = region.trimmingCharacters(in: .whitespacesAndNewlines)
        target.notes = notes
        target.expiryDate = hasExpiry ? expiryDate : nil
        target.tags = resolvedTags
        target.updatedAt = Date()

        // 主机或端口变化后，旧的探活结果不再可信。
        if connectionChanged {
            target.lastProbeAt = nil
            target.lastLatencyMs = nil
        }

        // 凭据只进 Keychain；数据库里始终只有认证方式。
        do {
            if authMode == .password {
                if !password.isEmpty {
                    try KeychainService.save(password, account: target.id.uuidString)
                }
            } else {
                KeychainService.delete(account: target.id.uuidString)
            }
        } catch {
            // 避免留下「密码认证但没有密码」的记录
            target.authMode = .keyAgent
            errorMessage = "无法写入 Keychain：\(error.localizedDescription)"
            return
        }

        do {
            try context.save()
        } catch {
            errorMessage = "保存失败：\(error.localizedDescription)"
            return
        }

        if server == nil {
            store.selectedServerID = target.id
        }
        store.showToast(server == nil ? "已添加 \(finalName)" : "已保存修改")
        dismiss()
    }

    private func saveWarnings(finalName: String, keyPath: String?) -> [String] {
        var warnings: [String] = []

        if let keyPath {
            let expanded = (keyPath as NSString).expandingTildeInPath
            if !FileManager.default.fileExists(atPath: expanded) {
                warnings.append("私钥文件不存在：\(keyPath)")
            }
        }

        let duplicate = allServers.contains {
            $0.id != server?.id && $0.name == finalName
        }
        if duplicate {
            warnings.append("已存在同名服务器「\(finalName)」，仍可继续保存。")
        }

        return warnings
    }

    private func resolveSelectedGroup() -> ServerGroup? {
        if let selectedGroupID {
            if let createdGroup, createdGroup.id == selectedGroupID {
                return createdGroup
            }
            return groups.first { $0.id == selectedGroupID }
        }
        return nil
    }

    /// 把标签文本变成实体：已存在则复用，不存在则新建。
    private func resolveTags() -> [Tag] {
        let names = Array(
            Set(
                tags
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        ).sorted()

        var result: [Tag] = []
        for name in names {
            let descriptor = FetchDescriptor<Tag>(
                predicate: #Predicate { $0.name == name }
            )
            if let existing = (try? context.fetch(descriptor))?.first {
                result.append(existing)
            } else {
                let tag = Tag(name: name)
                context.insert(tag)
                result.append(tag)
            }
        }
        return result
    }
}

// MARK: - 表单零件

/// 用于判断表单是否有未保存改动。
private struct FormSnapshot: Equatable {
    var name: String
    var host: String
    var domain: String
    var port: String
    var username: String
    var environmentRaw: String
    var groupID: UUID?
    var authModeRaw: String
    var password: String
    var privateKeyPath: String
    var owner: String
    var osVersion: String
    var region: String
    var notes: String
    var tags: [String]
    var hasExpiry: Bool
    var expiryDate: Date
}

private struct Field<Content: View>: View {
    let title: String
    var hint: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                if let hint {
                    Text(hint)
                        .font(.system(size: 10))
                        .foregroundStyle(.quaternary)
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension View {
    func scField() -> some View {
        textFieldStyle(.plain)
            .font(.system(size: 12.5))
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 7).fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7).strokeBorder(Theme.hairline)
            )
    }
}
