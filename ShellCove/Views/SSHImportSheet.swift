import SwiftData
import SwiftUI

/// SSH config 导入 Sheet（PRD FR-09）：只读解析 → 预览确认 → 完成汇总。
/// 文件不存在或无有效 Host 时给出说明，绝不显示空列表。
struct SSHImportSheet: View {
    enum Stage {
        case loading
        case failed(String)
        case ready([SSHConfigImporter.ParsedHost], skipped: Int)
        case done(added: Int, skipped: Int)
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var stage: Stage = .loading

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Theme.hairline).frame(height: 1)
            content
        }
        .frame(width: 560, height: 480)
        .task {
            if case .loading = stage { load() }
        }
    }

    // MARK: - 头部

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("从 SSH 配置导入")
                    .font(.system(size: 15, weight: .semibold))
                Text("只读取 ~/.ssh/config，不会修改该文件")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("关闭") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(18)
    }

    // MARK: - 分阶段内容

    @ViewBuilder
    private var content: some View {
        switch stage {
        case .loading:
            VStack(spacing: 12) {
                ProgressView()
                Text("正在解析 ~/.ssh/config …")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let message):
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 26))
                    .foregroundStyle(.tertiary)
                Text(message)
                    .font(.system(size: 12.5))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 30)
                HStack {
                    Button("重试") { load() }
                    Button("关闭") { dismiss() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .ready(let hosts, let skipped):
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(hosts.enumerated()), id: \.offset) { _, host in
                            hostRow(host)
                            Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 44)
                        }
                    }
                    .padding(.vertical, 6)
                }

                if skipped > 0 {
                    Text("已有 \(skipped) 台相同的服务器，将跳过。")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.top, 8)
                }

                Text("导入后将以 user@host:port 直连，不再经过 ssh config 的别名匹配（ProxyJump 等指令不生效）。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.top, 6)
                    .padding(.bottom, 12)

                HStack {
                    Button("取消", role: .cancel) { dismiss() }
                    Spacer()
                    Button("导入 \(hosts.count) 台") { performImport() }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                        .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
            }

        case .done(let added, let skipped):
            VStack(spacing: 14) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.accent)
                Text("新增 \(added) 台，跳过 \(skipped) 台")
                    .font(.system(size: 14, weight: .semibold))
                Text("新导入的服务器在「未分组」下，建议补充用途说明后归类。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                Button("完成") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .keyboardShortcut(.defaultAction)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func hostRow(_ host: SSHConfigImporter.ParsedHost) -> some View {
        HStack(spacing: 12) {
            IconTile(systemName: "terminal", size: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(host.alias)
                    .font(.system(size: 12.5, weight: .medium))
                HStack(spacing: 4) {
                    Text("\(host.user)@\(host.host)")
                    Text("· \(host.port)")
                }
                .font(.system(size: 10.8, design: .monospaced))
                .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 8)

            if let identityFile = host.identityFile {
                Text(identityFile)
                    .font(.system(size: 9.8, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
    }

    // MARK: - 动作

    private func load() {
        stage = .loading
        do {
            let hosts = try SSHConfigImporter.loadDefaultConfig()
            let existing = (try? context.fetch(FetchDescriptor<Server>())) ?? []
            let plan = SSHConfigImporter.makePlan(hosts: hosts, existingServers: existing)
            stage = .ready(plan.new, skipped: plan.skipped)
        } catch {
            stage = .failed(error.localizedDescription)
        }
    }

    private func performImport() {
        guard case .ready(let hosts, let skipped) = stage else { return }
        do {
            let added = try SSHConfigImporter.apply(hosts, context: context)
            stage = .done(added: added, skipped: skipped)
        } catch {
            stage = .failed("导入失败：\(error.localizedDescription)")
        }
    }
}
