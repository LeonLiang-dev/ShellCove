import Foundation
import SwiftData

/// 数据库 schema v1。
///
/// 模型嵌套在版本化 schema 内，后续字段演进通过新增 SchemaV2 + MigrationStage 完成，
/// 而不是直接修改已发布的模型定义（见 PRD 9.4）。
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [Server.self, ServerGroup.self, Tag.self, SessionRecord.self]
    }

    @Model
    final class Server {
        var id: UUID = UUID()
        var name: String = ""
        var host: String = ""
        var domain: String = ""
        var port: Int = 22
        var username: String = ""
        var environmentRaw: String = ServerEnvironment.development.rawValue
        var authModeRaw: String = AuthMode.keyAgent.rawValue
        var privateKeyPath: String?
        var notes: String = ""
        var owner: String = ""
        var expiryDate: Date?
        var osVersion: String = ""
        var region: String = ""
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        var lastConnectedAt: Date?
        var lastProbeAt: Date?
        var lastLatencyMs: Int?

        @Relationship(inverse: \ServerGroup.servers)
        var group: ServerGroup?

        var tags: [Tag] = []

        @Relationship(deleteRule: .cascade, inverse: \SessionRecord.server)
        var sessions: [SessionRecord] = []

        init(
            id: UUID = UUID(),
            name: String,
            host: String,
            domain: String = "",
            port: Int = 22,
            username: String,
            environment: ServerEnvironment = .development,
            authMode: AuthMode = .keyAgent,
            privateKeyPath: String? = nil,
            notes: String = "",
            owner: String = "",
            expiryDate: Date? = nil,
            osVersion: String = "",
            region: String = "",
            group: ServerGroup? = nil
        ) {
            self.id = id
            self.name = name
            self.host = host
            self.domain = domain
            self.port = port
            self.username = username
            self.environmentRaw = environment.rawValue
            self.authModeRaw = authMode.rawValue
            self.privateKeyPath = privateKeyPath
            self.notes = notes
            self.owner = owner
            self.expiryDate = expiryDate
            self.osVersion = osVersion
            self.region = region
            self.group = group
            self.createdAt = Date()
            self.updatedAt = Date()
        }

        var environment: ServerEnvironment {
            get { ServerEnvironment(rawValue: environmentRaw) ?? .development }
            set { environmentRaw = newValue.rawValue }
        }

        var authMode: AuthMode {
            get { AuthMode(rawValue: authModeRaw) ?? .keyAgent }
            set { authModeRaw = newValue.rawValue }
        }

        /// 列表中展示的主机文本：非默认端口时附带端口号。
        var hostLine: String {
            port == 22 ? host : "\(host):\(port)"
        }

        /// 复制到剪贴板的 ssh 命令（PRD 7.3 的基础形式）。
        var sshCommand: String {
            var parts = ["ssh", "-p", String(port)]
            if let privateKeyPath, !privateKeyPath.isEmpty {
                // 直接 execve 不会展开 ~，这里先转成绝对路径。
                parts.append(contentsOf: ["-i", (privateKeyPath as NSString).expandingTildeInPath])
            }
            parts.append("\(username)@\(host)")
            return parts.joined(separator: " ")
        }
    }

    @Model
    final class ServerGroup {
        var id: UUID = UUID()
        var name: String = ""
        var sortIndex: Int = 0
        var colorHex: String?
        var servers: [Server] = []

        init(id: UUID = UUID(), name: String, sortIndex: Int = 0, colorHex: String? = nil) {
            self.id = id
            self.name = name
            self.sortIndex = sortIndex
            self.colorHex = colorHex
        }
    }

    @Model
    final class Tag {
        var id: UUID = UUID()
        var name: String = ""

        @Relationship(inverse: \Server.tags)
        var servers: [Server] = []

        init(id: UUID = UUID(), name: String) {
            self.id = id
            self.name = name
        }
    }

    @Model
    final class SessionRecord {
        var id: UUID = UUID()
        var startedAt: Date = Date()
        var endedAt: Date?
        var durationSeconds: Int?
        var exitCode: Int32?
        var endReasonRaw: String = SessionEndReason.exited.rawValue
        var server: Server?

        init(
            id: UUID = UUID(),
            startedAt: Date = Date(),
            endedAt: Date? = nil,
            exitCode: Int32? = nil,
            endReason: SessionEndReason = .exited,
            server: Server? = nil
        ) {
            self.id = id
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.exitCode = exitCode
            self.endReasonRaw = endReason.rawValue
            self.server = server
        }

        var endReason: SessionEndReason {
            get { SessionEndReason(rawValue: endReasonRaw) ?? .interrupted }
            set { endReasonRaw = newValue.rawValue }
        }
    }
}

/// 迁移计划。首版只有 v1，stages 为空；后续版本在此追加。
enum ShellCoveMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
