import Foundation
import Observation
import SwiftData
import SwiftTerm

/// 单次终端会话的状态机（PRD 8.2）。
/// 负责创建 PTY、写入连接记录、把输出喂给 SwiftTerm。
@MainActor
@Observable
final class TerminalSessionModel {
    enum Phase: Equatable {
        case connecting
        case connected
        case ended(Int32?)
        case failed(String)
    }

    let server: Server
    private let context: ModelContext
    /// ssh 连接超时秒数（PRD FR-07），随会话创建时固定，重试沿用同一值。
    private let connectTimeout: Int
    private weak var terminalView: SwiftTerm.TerminalView?
    private var pty: PTYSession?
    private var record: SessionRecord?
    private var finalized = false
    private var didConnect = false
    private var hintBuffer = ""
    private var didEmitHint = false

    var phase: Phase = .connecting
    var startedAt = Date()
    /// 当前终端字符网格，底部状态栏展示用。
    private(set) var cols = 80
    private(set) var rows = 24

    init(server: Server, context: ModelContext, connectTimeout: Int = 10) {
        self.server = server
        self.context = context
        self.connectTimeout = connectTimeout
    }

    /// 终端视图创建后调用：拿到真实列数/行数再启动 ssh。
    func attach(_ view: SwiftTerm.TerminalView) {
        terminalView = view
        guard pty == nil, !finalized else { return }
        // 不在视图构建过程中改数据，推迟到下一个主线程周期。
        Task { @MainActor [weak self] in
            self?.start()
        }
    }

    func start() {
        guard pty == nil else { return }

        phase = .connecting
        didConnect = false
        hintBuffer = ""
        didEmitHint = false
        finalized = false
        startedAt = Date()

        var askPassPath: String?
        if server.authMode == .password {
            do {
                askPassPath = try AskPassInstaller.ensureScript()
            } catch {
                phase = .failed("无法准备密码助手")
                return
            }
        }

        let configuration = SSHCommandBuilder.launchConfiguration(
            for: server,
            askPassPath: askPassPath,
            connectTimeout: connectTimeout
        )

        let dimensions = terminalView?.terminalDimensions
        let cols = max(dimensions?.cols ?? 80, 20)
        let rows = max(dimensions?.rows ?? 24, 5)
        self.cols = cols
        self.rows = rows

        let record = SessionRecord(startedAt: startedAt, server: server)
        context.insert(record)
        try? context.save()
        self.record = record

        let session = PTYSession(
            configuration: configuration,
            cols: cols,
            rows: rows,
            onOutput: { [weak self] data in
                Task { @MainActor [weak self] in
                    self?.handleOutput(data)
                }
            },
            onExit: { [weak self] code in
                Task { @MainActor [weak self] in
                    self?.handleExit(code)
                }
            }
        )

        guard let session else {
            phase = .failed("无法创建终端会话")
            finalize(code: nil, reason: .interrupted)
            return
        }

        pty = session
    }

    func send(_ data: ArraySlice<UInt8>) {
        pty?.write(data)
    }

    func resize(cols: Int, rows: Int) {
        self.cols = cols
        self.rows = rows
        pty?.resize(cols: cols, rows: rows)
    }

    /// 复制当前终端缓冲区内容（不含样式）。
    func copyBuffer() -> String? {
        guard let view = terminalView else { return nil }
        let data = view.getBufferAsData(kind: .active)
        guard let text = String(data: data, encoding: .utf8),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return text
    }

    /// 用户主动返回详情或断开连接。
    func stop(reason: SessionEndReason = .userClosed) {
        pty?.terminate()
        if !finalized {
            finalize(code: nil, reason: reason)
        }
        pty = nil
        if case .failed = phase {
            // 保持失败状态，方便用户看到原因
        } else {
            phase = .ended(nil)
        }
    }

    func retry() {
        pty?.terminate()
        pty = nil
        record = nil
        finalized = false
        start()
    }

    // MARK: - 私有

    private func handleOutput(_ data: ArraySlice<UInt8>) {
        guard !finalized else { return }
        let chunk = String(decoding: data, as: UTF8.self)
        let isNoise = ConnectionHints.message(for: chunk, authMode: server.authMode) != nil
            || chunk.lowercased().contains("warning:")

        if !didConnect, !isNoise {
            didConnect = true
            phase = .connected
            // 收到第一段正常输出才算连接成功（PRD FR-05）。
            server.lastConnectedAt = Date()
            try? context.save()
        }

        terminalView?.feed(byteArray: data)

        guard !didEmitHint else { return }
        hintBuffer.append(chunk)
        if hintBuffer.count > 8192 {
            hintBuffer = String(hintBuffer.suffix(4096))
        }
        if let hint = ConnectionHints.message(for: hintBuffer, authMode: server.authMode) {
            didEmitHint = true
            terminalView?.feed(text: "\r\n\u{1B}[33m提示：\(hint)\u{1B}[0m\r\n")
        }
    }

    private func handleExit(_ code: Int32?) {
        guard !finalized else { return }
        terminalView?.feed(text: "\r\n\u{1B}[2m[连接已结束]\u{1B}[0m\r\n")
        let failed = !didConnect && (code ?? 1) != 0
        finalize(code: code, reason: failed ? .interrupted : .exited)
        if failed {
            phase = .failed("ssh 退出码 \(code ?? 1)")
        } else {
            phase = .ended(code)
        }
        pty = nil
    }

    private func finalize(code: Int32?, reason: SessionEndReason) {
        guard !finalized else { return }
        finalized = true
        guard let record else { return }

        let end = Date()
        record.endedAt = end
        record.durationSeconds = max(0, Int(end.timeIntervalSince(record.startedAt)))
        record.exitCode = code
        record.endReason = reason
        trimHistory()
        try? context.save()
    }

    /// 单台服务器只保留最近 200 条记录（PRD FR-06）。
    private func trimHistory() {
        let ordered = server.sessions.sorted { $0.startedAt > $1.startedAt }
        guard ordered.count > 200 else { return }
        for stale in ordered.dropFirst(200) {
            context.delete(stale)
        }
    }
}
