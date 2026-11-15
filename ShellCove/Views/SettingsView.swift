import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// 设置窗口（PRD FR-07）：外观、终端、连接、数据四个分区。
/// 数据区承载备份导出与导入（FR-08）。
struct SettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.modelContext) private var context

    /// 设置是独立 Scene，主窗口的 toast 在这里看不到；本地维护一份轻提示。
    @State private var feedback: String?
    @State private var feedbackTask: Task<Void, Never>?

    @State private var isExporting = false
    @State private var exportData: Data?
    @State private var isImporting = false
    @State private var pendingImport: BackupDocument?
    @State private var pendingPlan: BackupService.ImportPlan?
    /// 设置窗口自己的 SSH 导入 Sheet 状态；与主窗口的入口相互独立。
    @State private var isSSHImportPresented = false

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Picker("外观", selection: $settings.appearance) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("外观")
            } footer: {
                Text("终端始终保持深色背景，不随外观变化。")
            }

            Section {
                HStack {
                    Slider(value: $settings.terminalFontSize, in: SettingsStore.fontSizeRange, step: 0.5)
                    Text(String(format: "%.1f", settings.terminalFontSize))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .trailing)
                }
            } header: {
                Text("终端字号")
            } footer: {
                Text("正在使用的会话在下一次连接时生效。")
            }

            Section {
                Picker("连接超时", selection: $settings.connectTimeoutSeconds) {
                    ForEach([5, 10, 15, 30, 60], id: \.self) { seconds in
                        Text("\(seconds) 秒").tag(seconds)
                    }
                }
                Toggle("打开详情时自动检测连通性", isOn: $settings.autoProbeOnDetailOpen)
            } header: {
                Text("连接")
            } footer: {
                Text("超时只限制 TCP 建连阶段；自动检测关闭时，仍可手动点「检测」。")
            }

            Section {
                LabeledContent("数据库位置") {
                    Text(databasePath)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(databasePath)
                }
                HStack {
                    Button("在 Finder 中显示") { revealInFinder() }
                    Button("复制路径") { copyPath() }
                }
                HStack {
                    Button("导出备份…") { startExport() }
                    Button("导入备份…") { isImporting = true }
                }
                HStack {
                    Button("从 SSH 配置导入服务器…") { isSSHImportPresented = true }
                }
            } header: {
                Text("数据")
            } footer: {
                Text("所有数据只保存在本机。备份文件不含密码与私钥内容，导入时同名服务器会跳过。")
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .preferredColorScheme(settings.appearance.colorScheme)
        .fileExporter(
            isPresented: $isExporting,
            item: exportData,
            contentTypes: [.json],
            defaultFilename: "ShellCove-备份-\(Self.exportTimestamp()).json"
        ) { result in
            switch result {
            case .success:
                showFeedback("备份已导出")
            case .failure(let error):
                showFeedback("导出失败：\(error.localizedDescription)")
            }
            exportData = nil
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                loadImportCandidate(from: url)
            case .failure(let error):
                showFeedback("导入失败：\(error.localizedDescription)")
            }
        }
        .alert("导入备份", isPresented: importConfirmBinding) {
            Button("取消", role: .cancel) {
                pendingImport = nil
                pendingPlan = nil
            }
            Button("导入") { performImport() }
        } message: {
            Text(importConfirmMessage)
        }
        .sheet(isPresented: $isSSHImportPresented) {
            SSHImportSheet()
        }
        .overlay(alignment: .bottom) {
            ToastView(text: feedback)
                .padding(.bottom, 14)
                .animation(.easeOut(duration: 0.2), value: feedback)
                .allowsHitTesting(false)
        }
    }

    // MARK: - 数据分区

    private var databaseURL: URL? {
        context.container.configurations.first?.url
    }

    private var databasePath: String {
        databaseURL?.path ?? "未知"
    }

    private func revealInFinder() {
        guard let url = databaseURL else {
            showFeedback("未找到数据库位置")
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func copyPath() {
        guard let url = databaseURL else {
            showFeedback("未找到数据库位置")
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url.path, forType: .string)
        showFeedback("已复制数据库路径")
    }

    // MARK: - 备份导出 / 导入（PRD FR-08）

    private static func exportTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func startExport() {
        do {
            let document = try BackupService.makeDocument(context: context)
            exportData = try BackupService.encode(document)
            isExporting = true
        } catch {
            showFeedback("导出失败：\(error.localizedDescription)")
        }
    }

    private func loadImportCandidate(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let document = try BackupService.decode(data)
            let existing = (try? context.fetch(FetchDescriptor<Server>())) ?? []
            pendingImport = document
            pendingPlan = BackupService.makePlan(for: document, existingServers: existing)
        } catch {
            showFeedback("导入失败：\(error.localizedDescription)")
        }
    }

    private var importConfirmBinding: Binding<Bool> {
        Binding(
            get: { pendingImport != nil },
            set: { if !$0 { pendingImport = nil; pendingPlan = nil } }
        )
    }

    private var importConfirmMessage: String {
        guard let plan = pendingPlan else { return "" }
        if plan.newServers.isEmpty {
            return "备份中没有可导入的服务器（\(plan.skippedServerNames.count) 台同名服务器已存在，将跳过）。"
        }
        var text = "将新增 \(plan.newServers.count) 台服务器"
        if plan.sessionCount > 0 {
            text += "与 \(plan.sessionCount) 条连接记录"
        }
        if plan.skippedServerNames.isEmpty {
            text += "。分组与标签按名称复用。"
        } else {
            text += "；\(plan.skippedServerNames.count) 台同名服务器将跳过。分组与标签按名称复用。"
        }
        return text
    }

    private func performImport() {
        guard let document = pendingImport, let plan = pendingPlan else { return }
        do {
            let summary = try BackupService.apply(document, plan: plan, context: context)
            showFeedback("已导入 \(summary.addedServers) 台，跳过 \(summary.skippedServers) 台")
        } catch {
            showFeedback("导入失败：\(error.localizedDescription)")
        }
        pendingImport = nil
        pendingPlan = nil
    }

    // MARK: - 本地轻提示

    private func showFeedback(_ text: String) {
        feedback = text
        feedbackTask?.cancel()
        feedbackTask = Task {
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            feedback = nil
        }
    }
}
