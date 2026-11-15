import SwiftData
import XCTest

@testable import ShellCove

@MainActor
final class BackupServiceTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let container = try Persistence.makeContainer(inMemory: true)
        return ModelContext(container)
    }

    /// 固定时间戳，让 iso8601（秒级）往返后仍可精确比较。
    private static let base = Date(timeIntervalSince1970: 1_700_000_000)
    private static let later = Date(timeIntervalSince1970: 1_700_004_200)

    private func insertSampleData(into context: ModelContext) throws -> [Server] {
        let prod = ServerGroup(name: "生产环境", sortIndex: 0, colorHex: "#FF6B5E")
        let dev = ServerGroup(name: "开发环境", sortIndex: 2, colorHex: nil)
        context.insert(prod)
        context.insert(dev)
        let databaseTag = Tag(id: UUID(), name: "数据库")
        let cacheTag = Tag(id: UUID(), name: "缓存")
        context.insert(databaseTag)
        context.insert(cacheTag)

        let serverA = Server(
            name: "api-prod-01",
            host: "10.20.1.11",
            domain: "api.example.com",
            port: 2222,
            username: "deploy",
            environment: .production,
            authMode: .keyAgent,
            privateKeyPath: "~/.ssh/id_ed25519",
            notes: "主 API 网关",
            owner: "Leon",
            expiryDate: Self.base,
            osVersion: "Ubuntu 24.04",
            region: "上海 · 阿里云",
            group: prod
        )
        serverA.tags = [databaseTag]
        serverA.createdAt = Self.base
        serverA.updatedAt = Self.later
        serverA.lastConnectedAt = Self.later
        serverA.lastProbeAt = Self.later
        serverA.lastLatencyMs = 42
        context.insert(serverA)

        let serverB = Server(
            name: "redis-dev",
            host: "10.30.0.5",
            username: "ubuntu",
            environment: .development,
            authMode: .password,
            notes: "",
            group: dev
        )
        serverB.tags = [cacheTag]
        serverB.createdAt = Self.base
        serverB.updatedAt = Self.base
        context.insert(serverB)

        let exited = SessionRecord(
            startedAt: Self.base,
            endedAt: Self.later,
            exitCode: 0,
            endReason: .exited,
            server: serverA
        )
        exited.durationSeconds = 1800
        context.insert(exited)
        let interrupted = SessionRecord(
            startedAt: Self.base,
            endedAt: nil,
            exitCode: nil,
            endReason: .interrupted,
            server: serverB
        )
        context.insert(interrupted)

        try context.save()
        return [serverA, serverB]
    }

    // MARK: - 往返一致（AC-18）

    func testExportImportRoundTripRestoresEverything() throws {
        let source = try makeContext()
        let originals = try insertSampleData(into: source)

        let document = try BackupService.makeDocument(context: source)
        let data = try BackupService.encode(document)
        let restored = try BackupService.decode(data)
        let target = try makeContext()
        let plan = BackupService.makePlan(for: restored, existingServers: [])
        let summary = try BackupService.apply(restored, plan: plan, context: target)

        XCTAssertEqual(summary.addedServers, 2)
        XCTAssertEqual(summary.skippedServers, 0)
        XCTAssertEqual(summary.sessions, 2)

        let servers = try target.fetch(FetchDescriptor<Server>())
            .sorted { $0.name < $1.name }
        XCTAssertEqual(servers.count, 2)

        let importedA = try XCTUnwrap(servers.first { $0.name == "api-prod-01" })
        let originalA = try XCTUnwrap(originals.first { $0.name == "api-prod-01" })

        XCTAssertEqual(importedA.host, originalA.host)
        XCTAssertEqual(importedA.domain, originalA.domain)
        XCTAssertEqual(importedA.port, originalA.port)
        XCTAssertEqual(importedA.username, originalA.username)
        XCTAssertEqual(importedA.environment, originalA.environment)
        XCTAssertEqual(importedA.authMode, originalA.authMode)
        XCTAssertEqual(importedA.privateKeyPath, originalA.privateKeyPath)
        XCTAssertEqual(importedA.notes, originalA.notes)
        XCTAssertEqual(importedA.owner, originalA.owner)
        XCTAssertEqual(importedA.expiryDate, originalA.expiryDate)
        XCTAssertEqual(importedA.osVersion, originalA.osVersion)
        XCTAssertEqual(importedA.region, originalA.region)
        XCTAssertEqual(importedA.createdAt, originalA.createdAt)
        XCTAssertEqual(importedA.updatedAt, originalA.updatedAt)
        XCTAssertEqual(importedA.lastConnectedAt, originalA.lastConnectedAt)
        XCTAssertEqual(importedA.lastProbeAt, originalA.lastProbeAt)
        XCTAssertEqual(importedA.lastLatencyMs, originalA.lastLatencyMs)
        XCTAssertEqual(importedA.group?.name, "生产环境")
        XCTAssertEqual(Set(importedA.tags.map(\.name)), ["数据库"])

        let importedRecords = try target.fetch(FetchDescriptor<SessionRecord>())
        XCTAssertEqual(importedRecords.count, 2)
        let exitedRecord = try XCTUnwrap(importedRecords.first { $0.exitCode == 0 })
        XCTAssertEqual(exitedRecord.server?.name, "api-prod-01")
        XCTAssertEqual(exitedRecord.durationSeconds, 1800)
        XCTAssertEqual(exitedRecord.endReason, .exited)
        let interruptedRecord = try XCTUnwrap(importedRecords.first { $0.exitCode == nil })
        XCTAssertEqual(interruptedRecord.server?.name, "redis-dev")
        XCTAssertEqual(interruptedRecord.endReason, .interrupted)

        let groups = try target.fetch(FetchDescriptor<ServerGroup>())
        XCTAssertEqual(groups.count, 2)
        let tags = try target.fetch(FetchDescriptor<Tag>())
        XCTAssertEqual(tags.count, 2)
    }

    func testExportContainsNoSecrets() throws {
        let source = try makeContext()
        try insertSampleData(into: source)

        let document = try BackupService.makeDocument(context: source)
        let data = try BackupService.encode(document)
        let text = String(decoding: data, as: UTF8.self)

        // 密码只存 Keychain，数据库里没有；任何字段名都不能与密码相关，
        // 防止将来 DTO 演进时把敏感字段带进备份文件。
        let keys = try allJSONKeys(data)
        XCTAssertFalse(keys.contains { $0.lowercased().contains("password") })
        XCTAssertFalse(text.contains("PRIVATE KEY"))
        // 私钥「路径」是资料的一部分，应保留（PRD 7.1）。
        // JSONEncoder 会把 / 转义为 \/，所以只匹配文件名。
        XCTAssertTrue(text.contains("id_ed25519"))
        XCTAssertTrue(text.contains("version"))
    }

    /// 递归收集 JSON 的全部键名，用于「备份不含敏感字段」的回归闸。
    private func allJSONKeys(_ data: Data) throws -> Set<String> {
        let object = try JSONSerialization.jsonObject(with: data)
        var keys = Set<String>()

        func walk(_ value: Any) {
            if let dictionary = value as? [String: Any] {
                for (key, inner) in dictionary {
                    keys.insert(key)
                    walk(inner)
                }
            } else if let array = value as? [Any] {
                array.forEach(walk)
            }
        }

        walk(object)
        return keys
    }

    // MARK: - 导入校验

    func testHigherVersionIsRejectedWithReadableError() throws {
        var document = try minimalDocument()
        document.version = BackupDocument.currentVersion + 1
        let data = try BackupService.encode(document)

        var thrown: BackupService.ImportError?
        XCTAssertThrowsError(try BackupService.decode(data)) {
            thrown = $0 as? BackupService.ImportError
        }
        XCTAssertEqual(thrown, .unsupportedVersion(BackupDocument.currentVersion + 1))
        XCTAssertTrue(thrown?.errorDescription?.contains("v2") == true)
    }

    func testMalformedJSONThrowsAndKeepsStoreUntouched() throws {
        let target = try makeContext()
        try insertSampleData(into: target)

        XCTAssertThrowsError(try BackupService.decode(Data("{\"version\":1,".utf8)))

        let count = try target.fetch(FetchDescriptor<Server>()).count
        XCTAssertEqual(count, 2)
    }

    func testInvalidServerFieldsFailValidation() throws {
        var document = try minimalDocument()
        document.servers[0].port = 70000
        let data = try BackupService.encode(document)

        var thrown: BackupService.ImportError?
        XCTAssertThrowsError(try BackupService.decode(data)) {
            thrown = $0 as? BackupService.ImportError
        }
        guard case .invalid(let reason) = thrown else {
            return XCTFail("期望 .invalid，实际 \(String(describing: thrown))")
        }
        XCTAssertTrue(reason.contains("端口"))
    }

    func testDanglingGroupReferenceFailsValidation() throws {
        var document = try minimalDocument()
        document.servers[0].groupID = UUID()
        let data = try BackupService.encode(document)

        XCTAssertThrowsError(try BackupService.decode(data))
    }

    // MARK: - 同名与 UUID 冲突

    func testSameNameServersAreSkippedAndExistingDataKept() throws {
        let source = try makeContext()
        try insertSampleData(into: source)
        let document = try BackupService.makeDocument(context: source)
        let data = try BackupService.encode(document)

        let target = try makeContext()
        let original = try insertSampleData(into: target)
        // 本机只保留同名的 api-prod-01（带不同说明），redis-dev 应作为新增导入。
        if let redis = original.first(where: { $0.name == "redis-dev" }) {
            target.delete(redis)
        }
        let localAPI = try XCTUnwrap(target.fetch(FetchDescriptor<Server>()).first { $0.name == "api-prod-01" })
        localAPI.notes = "本机改过的说明"
        try target.save()

        let restored = try BackupService.decode(data)
        let plan = BackupService.makePlan(for: restored, existingServers: try target.fetch(FetchDescriptor<Server>()))
        XCTAssertEqual(plan.skippedServerNames, ["api-prod-01"])
        XCTAssertEqual(plan.newServers.map(\.name), ["redis-dev"])

        let summary = try BackupService.apply(restored, plan: plan, context: target)
        XCTAssertEqual(summary.addedServers, 1)
        XCTAssertEqual(summary.skippedServers, 1)

        let local = try XCTUnwrap(target.fetch(FetchDescriptor<Server>()).first { $0.name == "api-prod-01" })
        XCTAssertEqual(local.notes, "本机改过的说明")
    }

    func testUUIDCollisionIsRemappedWithSessionsAttached() throws {
        let source = try makeContext()
        let originals = try insertSampleData(into: source)
        let document = try BackupService.makeDocument(context: source)
        let data = try BackupService.encode(document)
        let restored = try BackupService.decode(data)

        // 目标库已存在同 UUID、不同名的服务器。
        let target = try makeContext()
        let collision = Server(
            id: originals[0].id,
            name: "另一台机器",
            host: "10.99.9.9",
            username: "root"
        )
        contextInsert(collision, into: target)

        let plan = BackupService.makePlan(for: restored, existingServers: [collision])
        let summary = try BackupService.apply(restored, plan: plan, context: target)

        XCTAssertEqual(summary.addedServers, 2)
        let servers = try target.fetch(FetchDescriptor<Server>())
        XCTAssertEqual(servers.count, 3)
        // 导入的 api-prod-01 换了新 UUID，连接记录挂在新对象上。
        let importedA = try XCTUnwrap(servers.first { $0.name == "api-prod-01" })
        XCTAssertNotEqual(importedA.id, collision.id)
        XCTAssertEqual(importedA.sessions.count, 1)
        XCTAssertEqual(collision.sessions.count, 0)
    }

    // MARK: - 辅助

    private func minimalDocument() throws -> BackupDocument {
        let groupID = UUID()
        return BackupDocument(
            version: BackupDocument.currentVersion,
            exportedAt: Self.base,
            groups: [GroupDTO(id: groupID, name: "生产环境", sortIndex: 0, colorHex: nil)],
            tags: [],
            servers: [
                ServerDTO(
                    id: UUID(),
                    name: "web",
                    host: "10.0.0.1",
                    domain: "",
                    port: 22,
                    username: "deploy",
                    environment: ServerEnvironment.production.rawValue,
                    authMode: AuthMode.keyAgent.rawValue,
                    privateKeyPath: nil,
                    notes: "",
                    owner: "",
                    expiryDate: nil,
                    osVersion: "",
                    region: "",
                    createdAt: Self.base,
                    updatedAt: Self.base,
                    lastConnectedAt: nil,
                    lastProbeAt: nil,
                    lastLatencyMs: nil,
                    groupID: groupID,
                    tagIDs: []
                )
            ],
            sessions: []
        )
    }

    private func contextInsert(_ server: Server, into context: ModelContext) {
        context.insert(server)
        try? context.save()
    }
}
