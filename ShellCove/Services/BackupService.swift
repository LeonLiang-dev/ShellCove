import Foundation
import SwiftData

/// 备份导出与导入（PRD FR-08 / AC-18）。
///
/// 导出：数据库 → DTO → JSON（不含密码与私钥内容）。
/// 导入：decode → validate → makePlan（纯计算）→ apply（全部插入后一次 save，
/// 任一步失败 rollback，不产生部分数据）。同名服务器默认跳过并汇总。
enum BackupService {
    enum ImportError: LocalizedError, Equatable {
        case unreadable
        case unsupportedVersion(Int)
        case invalid(String)

        var errorDescription: String? {
            switch self {
            case .unreadable:
                "无法读取备份文件，请确认它是 ShellCove 导出的 JSON 文件。"
            case .unsupportedVersion(let version):
                "备份文件版本 v\(version) 高于当前应用支持的 v\(BackupDocument.currentVersion)，"
                    + "请先升级 ShellCove 再导入。"
            case .invalid(let reason):
                "备份文件校验未通过：\(reason)"
            }
        }
    }

    /// 导入计划：哪些服务器新增、哪些同名跳过（PRD FR-08）。
    struct ImportPlan: Sendable, Equatable {
        var newServers: [ServerDTO]
        var skippedServerNames: [String]
        var sessionCount: Int
    }

    struct ImportSummary: Sendable, Equatable {
        var addedServers: Int
        var skippedServers: Int
        var sessions: Int
    }

    // MARK: - 导出

    /// 数据库快照转备份文档。只读不写，可在主线程调用。
    @MainActor
    static func makeDocument(context: ModelContext) throws -> BackupDocument {
        let servers = try context.fetch(FetchDescriptor<Server>())
        let groups = try context.fetch(FetchDescriptor<ServerGroup>())
        let tags = try context.fetch(FetchDescriptor<Tag>())
        let sessions = try context.fetch(FetchDescriptor<SessionRecord>())

        return BackupDocument(
            version: BackupDocument.currentVersion,
            exportedAt: Date(),
            groups: groups.map {
                GroupDTO(id: $0.id, name: $0.name, sortIndex: $0.sortIndex, colorHex: $0.colorHex)
            },
            tags: tags.map { TagDTO(id: $0.id, name: $0.name) },
            servers: servers.map { server in
                ServerDTO(
                    id: server.id,
                    name: server.name,
                    host: server.host,
                    domain: server.domain,
                    port: server.port,
                    username: server.username,
                    environment: server.environmentRaw,
                    authMode: server.authModeRaw,
                    privateKeyPath: server.privateKeyPath,
                    notes: server.notes,
                    owner: server.owner,
                    expiryDate: server.expiryDate,
                    osVersion: server.osVersion,
                    region: server.region,
                    createdAt: server.createdAt,
                    updatedAt: server.updatedAt,
                    lastConnectedAt: server.lastConnectedAt,
                    lastProbeAt: server.lastProbeAt,
                    lastLatencyMs: server.lastLatencyMs,
                    groupID: server.group?.id,
                    tagIDs: server.tags.map(\.id)
                )
            },
            sessions: sessions.compactMap { record in
                guard let server = record.server else { return nil }
                return SessionRecordDTO(
                    id: record.id,
                    startedAt: record.startedAt,
                    endedAt: record.endedAt,
                    durationSeconds: record.durationSeconds,
                    exitCode: record.exitCode,
                    endReason: record.endReasonRaw,
                    serverID: server.id
                )
            }
        )
    }

    static func encode(_ document: BackupDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        // 人可读、可 diff、键序稳定，方便用户查看与版本间对比。
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(document)
    }

    // MARK: - 导入

    /// 解码 + 版本检查 + 内容校验。失败抛出中文可读错误。
    static func decode(_ data: Data) throws -> BackupDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let document = try decoder.decode(BackupDocument.self, from: data)
            guard document.version <= BackupDocument.currentVersion else {
                throw ImportError.unsupportedVersion(document.version)
            }
            try validate(document)
            return document
        } catch let error as ImportError {
            throw error
        } catch {
            throw ImportError.unreadable
        }
    }

    static func validate(_ document: BackupDocument) throws {
        let groupIDs = Set(document.groups.map(\.id))
        let tagIDs = Set(document.tags.map(\.id))
        let serverIDs = Set(document.servers.map(\.id))

        for server in document.servers {
            let label = "「\(server.name)」"
            guard !server.host.trimmingCharacters(in: .whitespaces).isEmpty else {
                throw ImportError.invalid("\(label)缺少主机地址")
            }
            guard !server.username.trimmingCharacters(in: .whitespaces).isEmpty else {
                throw ImportError.invalid("\(label)缺少登录用户")
            }
            guard (1...65535).contains(server.port) else {
                throw ImportError.invalid("\(label)端口 \(server.port) 超出 1–65535 范围")
            }
            guard ServerEnvironment(rawValue: server.environment) != nil else {
                throw ImportError.invalid("\(label)环境标记无法识别")
            }
            guard AuthMode(rawValue: server.authMode) != nil else {
                throw ImportError.invalid("\(label)认证方式无法识别")
            }
            if let groupID = server.groupID, !groupIDs.contains(groupID) {
                throw ImportError.invalid("\(label)引用了备份中不存在的分组")
            }
            for tagID in server.tagIDs where !tagIDs.contains(tagID) {
                throw ImportError.invalid("\(label)引用了备份中不存在的标签")
            }
        }

        for session in document.sessions {
            guard serverIDs.contains(session.serverID) else {
                throw ImportError.invalid("连接记录引用了备份中不存在的服务器")
            }
        }
    }

    /// 计算导入计划（纯函数）：同名服务器跳过，其余新增（PRD FR-08）。
    static func makePlan(
        for document: BackupDocument,
        existingServers: [Server]
    ) -> ImportPlan {
        let existingNames = Set(existingServers.map(\.name))
        let newServers = document.servers.filter { !existingNames.contains($0.name) }
        let skippedNames = document.servers
            .filter { existingNames.contains($0.name) }
            .map(\.name)
        let newIDs = Set(newServers.map(\.id))
        let sessionCount = document.sessions.filter { newIDs.contains($0.serverID) }.count
        return ImportPlan(
            newServers: newServers,
            skippedServerNames: skippedNames,
            sessionCount: sessionCount
        )
    }

    /// 执行导入：全部插入后一次 save；中途失败 rollback，不产生部分数据。
    /// 分组与标签按名称复用；服务器 UUID 与库中冲突时换新 UUID 并重映射连接记录。
    @MainActor
    static func apply(
        _ document: BackupDocument,
        plan: ImportPlan,
        context: ModelContext
    ) throws -> ImportSummary {
        let existingServers = try context.fetch(FetchDescriptor<Server>())
        let existingNames = Set(existingServers.map(\.name))
        // 覆盖服务器与连接记录，用于 UUID 冲突检测。
        var usedIDs = Set(existingServers.map(\.id))
        let existingRecords = try context.fetch(FetchDescriptor<SessionRecord>())
        usedIDs.formUnion(existingRecords.map(\.id))

        let existingGroups = try context.fetch(FetchDescriptor<ServerGroup>())
        var usedGroupIDs = Set(existingGroups.map(\.id))
        let existingTags = try context.fetch(FetchDescriptor<Tag>())
        var usedTagIDs = Set(existingTags.map(\.id))

        var groupBySourceID = [UUID: ServerGroup]()
        var tagBySourceID = [UUID: Tag]()
        var serverBySourceID = [UUID: Server]()
        var addedServers = 0
        var addedSessions = 0

        do {
            // 分组：同名复用，否则新建。
            for dto in document.groups {
                if let existing = existingGroups.first(where: { $0.name == dto.name }) {
                    groupBySourceID[dto.id] = existing
                    continue
                }
                var groupID = dto.id
                if usedGroupIDs.contains(groupID) { groupID = UUID() }
                usedGroupIDs.insert(groupID)
                let group = ServerGroup(
                    id: groupID,
                    name: dto.name,
                    sortIndex: dto.sortIndex,
                    colorHex: dto.colorHex
                )
                context.insert(group)
                groupBySourceID[dto.id] = group
            }

            // 标签：同名复用，否则新建。
            for dto in document.tags {
                if let existing = existingTags.first(where: { $0.name == dto.name }) {
                    tagBySourceID[dto.id] = existing
                    continue
                }
                var tagID = dto.id
                if usedTagIDs.contains(tagID) { tagID = UUID() }
                usedTagIDs.insert(tagID)
                let tag = Tag(id: tagID, name: dto.name)
                context.insert(tag)
                tagBySourceID[dto.id] = tag
            }

            // 服务器：计划外同名再防御一次；UUID 冲突换新 UUID。
            for dto in plan.newServers where !existingNames.contains(dto.name) {
                let environment = ServerEnvironment(rawValue: dto.environment) ?? .development
                let authMode = AuthMode(rawValue: dto.authMode) ?? .keyAgent
                var serverID = dto.id
                if usedIDs.contains(serverID) { serverID = UUID() }
                usedIDs.insert(serverID)

                let server = Server(
                    id: serverID,
                    name: dto.name,
                    host: dto.host,
                    domain: dto.domain,
                    port: dto.port,
                    username: dto.username,
                    environment: environment,
                    authMode: authMode,
                    privateKeyPath: dto.privateKeyPath,
                    notes: dto.notes,
                    owner: dto.owner,
                    expiryDate: dto.expiryDate,
                    osVersion: dto.osVersion,
                    region: dto.region,
                    group: dto.groupID.flatMap { groupBySourceID[$0] }
                )
                server.tags = dto.tagIDs.compactMap { tagBySourceID[$0] }
                // 导出时快照的时间字段原样恢复，往返才完整（AC-18）。
                server.createdAt = dto.createdAt
                server.updatedAt = dto.updatedAt
                server.lastConnectedAt = dto.lastConnectedAt
                server.lastProbeAt = dto.lastProbeAt
                server.lastLatencyMs = dto.lastLatencyMs
                context.insert(server)
                serverBySourceID[dto.id] = server
                addedServers += 1
            }

            // 连接记录：只导入属于本次新增服务器的部分，被跳过的保留本机现状。
            for dto in document.sessions {
                guard let server = serverBySourceID[dto.serverID] else { continue }
                var recordID = dto.id
                if usedIDs.contains(recordID) { recordID = UUID() }
                usedIDs.insert(recordID)
                let record = SessionRecord(
                    id: recordID,
                    startedAt: dto.startedAt,
                    endedAt: dto.endedAt,
                    exitCode: dto.exitCode,
                    endReason: SessionEndReason(rawValue: dto.endReason) ?? .interrupted,
                    server: server
                )
                record.durationSeconds = dto.durationSeconds
                context.insert(record)
                addedSessions += 1
            }

            try context.save()
            return ImportSummary(
                addedServers: addedServers,
                skippedServers: plan.skippedServerNames.count,
                sessions: addedSessions
            )
        } catch {
            // 全量回滚：库里不会留下半份导入数据（PRD FR-08）。
            context.rollback()
            throw error
        }
    }
}
