import Darwin
import Foundation

/// 用伪终端拉起系统 ssh，并把读写两端交给上层。
/// 会话结束通过 onExit 回调一次退出码；fd 与子进程在结束路径上都会回收。
final class PTYSession: @unchecked Sendable {
    private let masterFD: Int32
    private let childPID: pid_t
    private let onOutput: @Sendable (ArraySlice<UInt8>) -> Void
    private let onExit: @Sendable (Int32?) -> Void
    private let lock = NSLock()
    private var source: DispatchSourceRead?
    private var finished = false

    init?(
        configuration: SSHLaunchConfiguration,
        cols: Int,
        rows: Int,
        onOutput: @escaping @Sendable (ArraySlice<UInt8>) -> Void,
        onExit: @escaping @Sendable (Int32?) -> Void
    ) {
        self.onOutput = onOutput
        self.onExit = onExit

        // fork 之后不能再做 Swift 侧的内存分配，所有 C 字符串都在 fork 前准备好。
        let executable = strdup(configuration.executable)
        var arguments = configuration.arguments.map { strdup($0) }
        arguments.append(nil)

        var environment = ProcessInfo.processInfo.environment
        environment.removeValue(forKey: "SSH_ASKPASS")
        environment.removeValue(forKey: "SSH_ASKPASS_REQUIRE")
        environment.removeValue(forKey: "SHELLCOVE_ACCOUNT")
        for (key, value) in configuration.environment {
            environment[key] = value
        }
        var environmentStrings = environment.map { strdup("\($0.key)=\($0.value)") }
        environmentStrings.append(nil)

        var master: Int32 = -1
        var size = winsize(
            ws_row: UInt16(clamping: rows),
            ws_col: UInt16(clamping: cols),
            ws_xpixel: 0,
            ws_ypixel: 0
        )

        let pid = forkpty(&master, nil, nil, &size)
        guard pid >= 0 else { return nil }

        if pid == 0 {
            execve(executable, &arguments, &environmentStrings)
            _exit(127)
        }

        childPID = pid
        masterFD = master

        let queue = DispatchQueue(label: "dev.leon.shellcove.pty")
        let readSource = DispatchSource.makeReadSource(fileDescriptor: master, queue: queue)
        readSource.setEventHandler { [weak self] in
            self?.readAvailable()
        }
        readSource.setCancelHandler {
            Darwin.close(master)
        }
        source = readSource
        readSource.resume()
    }

    deinit {
        source?.cancel()
        lock.lock()
        let running = !finished
        lock.unlock()
        if running {
            kill(childPID, SIGHUP)
        }
    }

    // MARK: - 输出

    private func readAvailable() {
        var buffer = [UInt8](repeating: 0, count: 32768)
        let count = buffer.withUnsafeMutableBytes { raw in
            Darwin.read(masterFD, raw.baseAddress, raw.count)
        }

        if count > 0 {
            onOutput(buffer[0..<count])
        } else if count == 0 {
            finish(waitForExit: true)
        } else if errno != EAGAIN && errno != EINTR {
            finish(waitForExit: true)
        }
    }

    // MARK: - 输入

    func write(_ data: ArraySlice<UInt8>) {
        lock.lock()
        let running = !finished
        lock.unlock()
        guard running else { return }

        data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            var offset = 0
            while offset < raw.count {
                let written = Darwin.write(
                    masterFD,
                    base.advanced(by: offset),
                    raw.count - offset
                )
                if written > 0 {
                    offset += written
                } else if written < 0 && errno == EINTR {
                    continue
                } else {
                    break
                }
            }
        }
    }

    func resize(cols: Int, rows: Int) {
        guard cols > 0, rows > 0 else { return }
        var size = winsize(
            ws_row: UInt16(clamping: rows),
            ws_col: UInt16(clamping: cols),
            ws_xpixel: 0,
            ws_ypixel: 0
        )
        _ = ioctl(masterFD, TIOCSWINSZ, &size)
    }

    /// 请求结束会话：先礼后兵，SIGHUP 让 ssh 自己收尾。
    func terminate() {
        lock.lock()
        let running = !finished
        lock.unlock()
        guard running else { return }
        kill(childPID, SIGHUP)
    }

    // MARK: - 结束

    private func finish(waitForExit: Bool) {
        lock.lock()
        if finished {
            lock.unlock()
            return
        }
        finished = true
        let readSource = source
        source = nil
        lock.unlock()

        readSource?.cancel()

        var code: Int32?
        if waitForExit {
            var status: Int32 = 0
            let result = waitpid(childPID, &status, 0)
            if result == childPID {
                let signal = status & 0x7F
                if signal == 0 {
                    code = (status >> 8) & 0xFF
                } else {
                    code = 128 + signal
                }
            }
        }

        onExit(code)
    }
}
