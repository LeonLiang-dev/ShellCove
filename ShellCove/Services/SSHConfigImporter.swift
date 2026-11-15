import Foundation
import SwiftData

/// 只读解析并导入 `~/.ssh/config`（PRD FR-09）。
///
/// 解析规则（保守、可解释）：
/// - keyword 大小写不敏感，支持 `Host web` 与 `Host=web` 两种写法；
/// - 含通配符（`*` / `?`）的 Host 块整体跳过，包括 `Host *` 兜底块；
/// - `Include` 不递归展开；`Match`、`ProxyJump` 等其他指令忽略；
/// - `HostName` 缺失时主机名回退为别名（与 ssh 本身语义一致）；
/// - 多别名取第一个；块内多个 IdentityFile 取第一个；
/// - 只有 `#` 开头的行是注释；解析全程绝不回写用户配置文件。
enum SSHConfigImporter {
    struct ParsedHost: Equatable, Sendable {
        var alias: String
        /// HostName；缺失时等于 alias。
        var host: String
        var user: String
        var port: Int
        var identityFile: String?
    }

    enum ImportError: LocalizedError, Equatable {
        case fileNotFound
        case noValidHosts
        case readFailed(String)

        var errorDescription: String? {
            switch self {
            case .fileNotFound:
                "没有找到 ~/.ssh/config 文件。可以先创建一个，再回到这里导入。"
            case .noValidHosts:
                "SSH 配置文件里没有可导入的 Host 条目（含通配符的条目会被跳过）。"
            case .readFailed(let reason):
                "无法读取 SSH 配置文件：\(reason)"
            }
        }
    }

    // MARK: - 解析（纯函数）

    static func parse(text: String) -> [ParsedHost] {
        var hosts: [ParsedHost] = []
        var current: ParsedHost?

        func flush() {
            if let host = current { hosts.append(host) }
            current = nil
        }

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            // OpenSSH 规则：空行与 # 开头的行是注释；行中 # 不做剥离。
            if line.isEmpty || line.hasPrefix("#") { continue }

            // 统一 `Keyword=value` 与 `Keyword value` 两种分隔形式。
            let normalized = line.replacingOccurrences(of: "=", with: " ")
            let tokens = normalized
                .split(separator: " ", omittingEmptySubsequences: true)
                .map(String.init)
            guard let keyword = tokens.first?.lowercased(), tokens.count > 1 else { continue }

            switch keyword {
            case "host":
                flush()
                guard let alias = tokens.dropFirst().first else { continue }
                // 通配符块整体跳过：current 保持 nil，块内后续指令自然被忽略。
                if alias.contains("*") || alias.contains("?") { continue }
                current = ParsedHost(
                    alias: alias,
                    host: alias,
                    user: NSUserName(),
                    port: 22,
                    identityFile: nil
                )
            case "hostname":
                current?.host = tokens[1]
            case "user":
                current?.user = tokens[1]
            case "port":
                if let port = Int(tokens[1]), (1...65535).contains(port) {
                    current?.port = port
                }
            case "identityfile":
                if current?.identityFile == nil {
                    current?.identityFile = tokens.dropFirst().first
                }
            default:
                // Include / Match / ProxyJump 等其他指令一律忽略。
                continue
            }
        }
        flush()
        return hosts
    }

    // MARK: - 文件读取

    /// 解析指定路径的 config 文件；文件不存在与读取失败分别给出明确错误。
    static func parseFile(at url: URL) throws -> [ParsedHost] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ImportError.fileNotFound
        }
        let text: String
        do {
            text = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw ImportError.readFailed(error.localizedDescription)
        }
        return parse(text: text)
    }

    /// 读取默认的 ~/.ssh/config 并校验至少有一个可导入条目。
    static func loadDefaultConfig() throws -> [ParsedHost] {
        let path = ("~/.ssh/config" as NSString).expandingTildeInPath
        let hosts = try parseFile(at: URL(fileURLWithPath: path))
        guard !hosts.isEmpty else { throw ImportError.noValidHosts }
        return hosts
    }

    // MARK: - 判重与落库

    /// 判重键：主机 + 端口 + 用户（PRD FR-09）。
    static func dedupKey(host: String, port: Int, user: String) -> String {
        "\(host)|\(port)|\(user)"
    }

    /// 计算导入计划：与库中已有服务器按三元组判重，文件内部同样去重。
    static func makePlan(
        hosts: [ParsedHost],
        existingServers: [Server]
    ) -> (new: [ParsedHost], skipped: Int) {
        let existingKeys = Set(
            existingServers.map { dedupKey(host: $0.host, port: $0.port, user: $0.username) }
        )
        var seenKeys = Set<String>()
        var new: [ParsedHost] = []
        var skipped = 0

        for host in hosts {
            let key = dedupKey(host: host.host, port: host.port, user: host.user)
            if existingKeys.contains(key) || !seenKeys.insert(key).inserted {
                skipped += 1
                continue
            }
            new.append(host)
        }
        return (new, skipped)
    }

    /// 落库：认证方式一律 SSH Key / agent，分组留空（未分组），
    /// 让用户显式整理而不是批量塞进某个环境（PRD 7.1）。
    @MainActor
    static func apply(_ hosts: [ParsedHost], context: ModelContext) throws -> Int {
        for host in hosts {
            let server = Server(
                name: host.alias,
                host: host.host,
                port: host.port,
                username: host.user,
                environment: .development,
                authMode: .keyAgent,
                privateKeyPath: host.identityFile,
                group: nil
            )
            context.insert(server)
        }
        try context.save()
        return hosts.count
    }
}
