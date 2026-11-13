import AppKit
import SwiftData
import SwiftTerm
import SwiftUI

/// 终端覆盖整个右栏（PRD FR-05）。
struct TerminalPane: View {
    let server: Server

    @Environment(AppStore.self) private var store
    @Environment(\.modelContext) private var context

    @State private var model: TerminalSessionModel?

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(SwiftUI.Color.white.opacity(0.08)).frame(height: 1)

            ZStack {
                TerminalTheme.background
                if let model {
                    TerminalRepresentable(model: model)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .colorScheme(.dark)
                }
            }

            Rectangle().fill(SwiftUI.Color.white.opacity(0.07)).frame(height: 1)
            footer
        }
        .background(TerminalTheme.background)
        .task {
            if model == nil {
                model = TerminalSessionModel(server: server, context: context)
            }
        }
        .onDisappear {
            model?.stop(reason: .userClosed)
        }
    }

    // MARK: - 头部

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                store.closeTerminal()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("详情")
                        .font(.system(size: 11.5))
                }
                .frame(height: 26)
                .padding(.horizontal, 9)
                .background(
                    RoundedRectangle(cornerRadius: 6).fill(SwiftUI.Color.white.opacity(0.06))
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(SwiftUI.Color.white.opacity(0.72))
            .help("返回服务器详情")

            HStack(spacing: 7) {
                Circle()
                    .fill(stateColor)
                    .frame(width: 6, height: 6)
                Text(server.name)
                    .font(.system(size: 11.5))
                    .foregroundStyle(SwiftUI.Color(red: 0.91, green: 0.92, blue: 0.93))
            }
            .frame(height: 26)
            .padding(.horizontal, 11)
            .background(
                RoundedRectangle(cornerRadius: 6).fill(SwiftUI.Color.white.opacity(0.07))
            )

            Spacer()

            Text("ssh · \(server.port)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(SwiftUI.Color.white.opacity(0.32))

            TerminalIconButton(systemName: "doc.on.doc", help: "复制终端内容") {
                copyTerminal()
            }

            TerminalIconButton(systemName: "xmark", help: "断开连接") {
                store.closeTerminal()
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(SwiftUI.Color.white.opacity(0.022))
    }

    private func copyTerminal() {
        guard let text = model?.copyBuffer() else {
            store.showToast("终端暂无内容")
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        store.showToast("已复制终端内容")
    }

    // MARK: - 底部状态栏

    private var footer: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(stateColor)
                .frame(width: 5, height: 5)
            Text(stateLabel)

            footerSeparator
            Text("\(server.username)@\(server.host)")

            footerSeparator
            Text(server.authMode.displayName)

            footerSeparator
            Text("\(model?.cols ?? 80)×\(model?.rows ?? 24)")

            Spacer()

            if canRetry {
                Button("重新连接") {
                    model?.retry()
                }
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundStyle(TerminalTheme.accent)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 26)
        .font(.system(size: 9.8, design: .monospaced))
        .foregroundStyle(SwiftUI.Color.white.opacity(0.3))
        .background(SwiftUI.Color.white.opacity(0.015))
    }

    private var footerSeparator: some View {
        Rectangle()
            .fill(SwiftUI.Color.white.opacity(0.1))
            .frame(width: 1, height: 10)
    }

    // MARK: - 状态

    private var stateLabel: String {
        guard let phase = model?.phase else { return "正在准备终端" }
        switch phase {
        case .connecting:
            return "正在连接…"
        case .connected:
            return "已连接"
        case .ended(let code):
            return code.map { "已断开 · exit \($0)" } ?? "已断开"
        case .failed(let message):
            return "连接失败 · \(message)"
        }
    }

    private var stateColor: SwiftUI.Color {
        guard let phase = model?.phase else { return SwiftUI.Color.white.opacity(0.4) }
        switch phase {
        case .connecting:
            return SwiftUI.Color(red: 1.0, green: 0.70, blue: 0.25)
        case .connected:
            return SwiftUI.Color(red: 0.204, green: 0.780, blue: 0.349)
        case .ended:
            return SwiftUI.Color.white.opacity(0.35)
        case .failed:
            return SwiftUI.Color(red: 1.0, green: 0.42, blue: 0.37)
        }
    }

    private var canRetry: Bool {
        guard let phase = model?.phase else { return false }
        switch phase {
        case .ended, .failed:
            return true
        case .connecting, .connected:
            return false
        }
    }
}

// MARK: - SwiftTerm 桥接

private enum TerminalTheme {
    static let background = SwiftUI.Color(red: 0.055, green: 0.063, blue: 0.075)
    static let foreground = SwiftUI.Color(red: 0.84, green: 0.86, blue: 0.88)
    static let accent = SwiftUI.Color(red: 0.35, green: 0.85, blue: 0.78)

    static let backgroundNS = NSColor(
        srgbRed: 0.055, green: 0.063, blue: 0.075, alpha: 1
    )
    static let foregroundNS = NSColor(
        srgbRed: 0.84, green: 0.86, blue: 0.88, alpha: 1
    )

    /// 与原型终端里的绿/黄/青/蓝保持一致。
    static let ansiPalette: [SwiftTerm.Color] = [
        SwiftTerm.Color(red8: 0x1E, green8: 0x21, blue8: 0x26),
        SwiftTerm.Color(red8: 0xFF, green8: 0x6B, blue8: 0x5E),
        SwiftTerm.Color(red8: 0x63, green8: 0xD6, blue8: 0x7F),
        SwiftTerm.Color(red8: 0xFF, green8: 0xCF, blue8: 0x6B),
        SwiftTerm.Color(red8: 0x6F, green8: 0xB5, blue8: 0xFF),
        SwiftTerm.Color(red8: 0xA7, green8: 0x8B, blue8: 0xFA),
        SwiftTerm.Color(red8: 0x5F, green8: 0xD7, blue8: 0xD3),
        SwiftTerm.Color(red8: 0xD5, green8: 0xD9, blue8: 0xDE),
        SwiftTerm.Color(red8: 0x5C, green8: 0x63, blue8: 0x6E),
        SwiftTerm.Color(red8: 0xFF, green8: 0x8A, blue8: 0x80),
        SwiftTerm.Color(red8: 0x86, green8: 0xE3, blue8: 0x9A),
        SwiftTerm.Color(red8: 0xFF, green8: 0xDE, blue8: 0x9A),
        SwiftTerm.Color(red8: 0x93, green8: 0xC8, blue8: 0xFF),
        SwiftTerm.Color(red8: 0xC3, green8: 0xAE, blue8: 0xFF),
        SwiftTerm.Color(red8: 0x8B, green8: 0xE9, blue8: 0xE4),
        SwiftTerm.Color(red8: 0xF1, green8: 0xF2, blue8: 0xF4)
    ]
}

private struct TerminalRepresentable: NSViewRepresentable {
    let model: TerminalSessionModel

    func makeNSView(context: Context) -> SwiftTerm.TerminalView {
        let view = SwiftTerm.TerminalView(
            frame: .zero,
            font: NSFont.monospacedSystemFont(ofSize: 12.2, weight: .regular)
        )
        view.terminalDelegate = context.coordinator
        // 终端始终是深色，不跟随浅色外观（PRD FR-05）。
        view.nativeBackgroundColor = TerminalTheme.backgroundNS
        view.nativeForegroundColor = TerminalTheme.foregroundNS
        view.caretColor = TerminalTheme.foregroundNS
        view.lineSpacing = 1.4
        view.installColors(TerminalTheme.ansiPalette)

        model.attach(view)

        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: SwiftTerm.TerminalView, context: Context) {
        context.coordinator.model = model
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    @MainActor
    final class Coordinator: NSObject, TerminalViewDelegate {
        var model: TerminalSessionModel

        init(model: TerminalSessionModel) {
            self.model = model
        }

        func sizeChanged(source: SwiftTerm.TerminalView, newCols: Int, newRows: Int) {
            model.resize(cols: newCols, rows: newRows)
        }

        func setTerminalTitle(source: SwiftTerm.TerminalView, title: String) {}

        func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {}

        func send(source: SwiftTerm.TerminalView, data: ArraySlice<UInt8>) {
            model.send(data)
        }

        func scrolled(source: SwiftTerm.TerminalView, position: Double) {}

        func rangeChanged(source: SwiftTerm.TerminalView, startY: Int, endY: Int) {}
    }
}

// MARK: - 头部图标按钮

private struct TerminalIconButton: View {
    let systemName: String
    let help: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(SwiftUI.Color.white.opacity(hovering ? 0.09 : 0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(SwiftUI.Color.white.opacity(hovering ? 1 : 0.45))
        .onHover { hovering = $0 }
        .help(help)
    }
}
