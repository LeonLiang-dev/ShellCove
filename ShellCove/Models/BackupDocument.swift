import Foundation

/// 备份文件格式（PRD FR-08）。
///
/// 纯 Codable DTO，与 SwiftData 模型解耦：格式可随版本演进，模型不用动。
/// 安全边界由结构本身保证：没有密码字段（密码只存 Keychain，从不进数据库），
/// privateKeyPath 只是路径引用，不包含任何私钥文件内容。
struct BackupDocument: Codable, Sendable, Equatable {
    /// 格式版本号。导入时高于 currentVersion 的文件会被拒绝。
    static let currentVersion = 1

    var version: Int
    var exportedAt: Date
    var groups: [GroupDTO]
    var tags: [TagDTO]
    var servers: [ServerDTO]
    var sessions: [SessionRecordDTO]
}

struct GroupDTO: Codable, Sendable, Equatable {
    var id: UUID
    var name: String
    var sortIndex: Int
    var colorHex: String?
}

struct TagDTO: Codable, Sendable, Equatable {
    var id: UUID
    var name: String
}

struct ServerDTO: Codable, Sendable, Equatable {
    var id: UUID
    var name: String
    var host: String
    var domain: String
    var port: Int
    var username: String
    var environment: String
    var authMode: String
    var privateKeyPath: String?
    var notes: String
    var owner: String
    var expiryDate: Date?
    var osVersion: String
    var region: String
    var createdAt: Date
    var updatedAt: Date
    var lastConnectedAt: Date?
    var lastProbeAt: Date?
    var lastLatencyMs: Int?
    var groupID: UUID?
    var tagIDs: [UUID]
}

struct SessionRecordDTO: Codable, Sendable, Equatable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var durationSeconds: Int?
    var exitCode: Int32?
    var endReason: String
    var serverID: UUID
}
