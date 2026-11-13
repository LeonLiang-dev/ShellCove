import AppKit
import SwiftUI

/// ⌘K 搜索面板。使用 AppKit 文本框以可靠地拦截 ↑ ↓ ↵ Esc。
struct CommandPalette: View {
    let servers: [Server]

    @Environment(AppStore.self) private var store
    @State private var query = ""
    @State private var highlighted = 0

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.16)
                .ignoresSafeArea()
                .onTapGesture { close() }

            panel
                .padding(.top, 68)
                .transition(.opacity.combined(with: .scale(scale: 0.985, anchor: .top)))
        }
    }

    private var panel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)

                PaletteSearchField(
                    text: $query,
                    onSubmit: submit,
                    onMove: move,
                    onCancel: close
                )
                .frame(height: 22)

                Text("esc")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 4).fill(Theme.surfaceStrong)
                    )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Rectangle().fill(Theme.hairline).frame(height: 1)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        if results.isEmpty {
                            Text("未找到匹配的服务器")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                        } else {
                            ForEach(Array(results.enumerated()), id: \.element.id) { index, server in
                                resultRow(server, isHighlighted: index == highlighted)
                                    .id(server.id)
                                    .onTapGesture { choose(server) }
                            }
                        }
                    }
                    .padding(6)
                }
                .frame(maxHeight: 322)
                .onChange(of: highlighted) { _, newValue in
                    guard results.indices.contains(newValue) else { return }
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(results[newValue].id, anchor: .center)
                    }
                }
            }

            Rectangle().fill(Theme.hairline).frame(height: 1)

            HStack(spacing: 14) {
                hint("↑ ↓", "选择")
                hint("↵", "打开")
                hint("⌘K", "关闭")
                Spacer()
                Text("\(results.count) 个结果")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(width: 560)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 13))
        .overlay(
            RoundedRectangle(cornerRadius: 13).strokeBorder(Theme.hairline)
        )
        .shadow(color: .black.opacity(0.24), radius: 28, y: 12)
        .onChange(of: query) { _, _ in
            highlighted = 0
        }
    }

    private func resultRow(_ server: Server, isHighlighted: Bool) -> some View {
        HStack(spacing: 10) {
            IconTile(systemName: "server.rack", size: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(server.name)
                    .font(.system(size: 12.5, weight: .medium))
                    .lineLimit(1)
                Text("\(server.username)@\(server.host)")
                    .font(.system(size: 10.2, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            EnvPill(environment: server.environment)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isHighlighted ? Theme.accent.opacity(0.14) : Color.clear)
        )
        .contentShape(Rectangle())
    }

    private func hint(_ keys: String, _ label: String) -> some View {
        HStack(spacing: 5) {
            Text(keys)
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3).fill(Theme.surfaceStrong)
                )
            Text(label)
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - 结果

    private var results: [Server] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return Array(
                servers
                    .sorted { ($0.lastConnectedAt ?? .distantPast) > ($1.lastConnectedAt ?? .distantPast) }
                    .prefix(5)
            )
        }

        let needle = trimmed.lowercased()
        let matched = servers.filter { server in
            let haystack = [
                server.name,
                server.host,
                server.domain,
                server.username,
                server.owner,
                server.region,
                server.tags.map(\.name).joined(separator: " ")
            ].joined(separator: " ").lowercased()
            return haystack.contains(needle)
        }

        return Array(
            matched
                .sorted { lhs, rhs in
                    let lp = lhs.name.lowercased().hasPrefix(needle)
                    let rp = rhs.name.lowercased().hasPrefix(needle)
                    if lp != rp { return lp }
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
                .prefix(8)
        )
    }

    private func move(_ delta: Int) {
        guard !results.isEmpty else { return }
        let next = highlighted + delta
        highlighted = min(max(next, 0), results.count - 1)
    }

    private func submit() {
        guard results.indices.contains(highlighted) else { return }
        choose(results[highlighted])
    }

    private func choose(_ server: Server) {
        store.clearFilters()
        store.select(server)
        close()
    }

    private func close() {
        store.isPalettePresented = false
    }
}

// MARK: - AppKit 搜索框

/// 用 NSTextField 接收键盘命令，保证 ↑ ↓ ↵ Esc 不被文本编辑器吞掉。
struct PaletteSearchField: NSViewRepresentable {
    @Binding var text: String
    var onSubmit: () -> Void
    var onMove: (Int) -> Void
    var onCancel: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 14)
        field.placeholderString = "搜索服务器、主机、标签…"
        field.delegate = context.coordinator
        field.stringValue = text
        field.cell?.usesSingleLineMode = true

        DispatchQueue.main.async {
            field.window?.makeFirstResponder(field)
        }
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.parent = self
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        // 面板刚插入时窗口可能还不存在，这里补一次聚焦，保证键盘优先。
        if !context.coordinator.didFocus, nsView.window != nil {
            context.coordinator.didFocus = true
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: PaletteSearchField
        var didFocus = false

        init(_ parent: PaletteSearchField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.moveUp(_:)):
                parent.onMove(-1)
                return true
            case #selector(NSResponder.moveDown(_:)):
                parent.onMove(1)
                return true
            case #selector(NSResponder.insertNewline(_:)):
                parent.onSubmit()
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                parent.onCancel()
                return true
            default:
                return false
            }
        }
    }
}
