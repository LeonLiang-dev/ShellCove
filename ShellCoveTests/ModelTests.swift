import SwiftData
import XCTest

@testable import ShellCove

final class ModelTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let container = try Persistence.makeContainer(inMemory: true)
        return ModelContext(container)
    }

    func testServerFieldsArePersisted() throws {
        let context = try makeContext()
        let group = ServerGroup(name: "生产环境", sortIndex: 0, colorHex: "#FF6B5E")
        context.insert(group)

        let server = Server(
            name: "api-prod-01",
            host: "10.20.1.11",
            domain: "api.example.com",
            port: 22,
            username: "deploy",
            environment: .production,
            notes: "主 API 网关",
            group: group
        )
        context.insert(server)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Server>())
        XCTAssertEqual(fetched.count, 1)

        let saved = try XCTUnwrap(fetched.first)
        XCTAssertEqual(saved.name, "api-prod-01")
        XCTAssertEqual(saved.hostLine, "10.20.1.11")
        XCTAssertEqual(saved.environment, .production)
        XCTAssertEqual(saved.notes, "主 API 网关")
        XCTAssertEqual(saved.group?.name, "生产环境")
        XCTAssertEqual(saved.group?.servers.count, 1)
    }

    func testUnknownEnvironmentFallsBackToDevelopment() throws {
        let context = try makeContext()
        let server = Server(name: "x", host: "127.0.0.1", username: "root")
        context.insert(server)
        try context.save()

        server.environmentRaw = "something-else"
        XCTAssertEqual(server.environment, .development)
    }

    func testPasswordAuthModeRoundTrip() throws {
        let context = try makeContext()
        let server = Server(
            name: "legacy-vps",
            host: "10.0.0.9",
            username: "root",
            environment: .production,
            authMode: .password
        )
        context.insert(server)
        try context.save()

        let fetched = try XCTUnwrap(try context.fetch(FetchDescriptor<Server>()).first)
        XCTAssertEqual(fetched.authMode, .password)
        XCTAssertEqual(fetched.authModeRaw, "password")
        XCTAssertNil(fetched.privateKeyPath)
    }

    func testNonDefaultPortAppearsInHostLineAndCommand() throws {
        let context = try makeContext()
        let server = Server(
            name: "sandbox",
            host: "192.168.50.20",
            port: 2222,
            username: "leon",
            privateKeyPath: "/Users/leon/.ssh/id_ed25519"
        )
        context.insert(server)
        try context.save()

        XCTAssertEqual(server.hostLine, "192.168.50.20:2222")
        XCTAssertEqual(
            server.sshCommand,
            "ssh -p 2222 -i /Users/leon/.ssh/id_ed25519 leon@192.168.50.20"
        )
    }

    func testDeletingServerCascadesSessionsButKeepsGroup() throws {
        let context = try makeContext()
        let group = ServerGroup(name: "测试环境")
        context.insert(group)

        let server = Server(name: "ci-02", host: "10.30.2.18", username: "runner", group: group)
        context.insert(server)

        let record = SessionRecord(startedAt: .now, server: server)
        context.insert(record)
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<SessionRecord>()).count, 1)

        context.delete(server)
        try context.save()

        XCTAssertTrue(try context.fetch(FetchDescriptor<SessionRecord>()).isEmpty)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ServerGroup>()).count, 1)
    }

    func testTagRelationshipIsBidirectional() throws {
        let context = try makeContext()
        let tag = Tag(name: "数据库")
        let server = Server(name: "db-01", host: "10.20.1.31", username: "dba")
        context.insert(tag)
        context.insert(server)

        server.tags.append(tag)
        try context.save()

        let fetchedTag = try XCTUnwrap(try context.fetch(FetchDescriptor<Tag>()).first)
        XCTAssertEqual(fetchedTag.servers.count, 1)
        XCTAssertEqual(fetchedTag.servers.first?.name, "db-01")
        XCTAssertEqual(try context.fetch(FetchDescriptor<Server>()).first?.tags.count, 1)
    }

    func testSchemaVersionIsOne() {
        XCTAssertEqual(SchemaV1.versionIdentifier, Schema.Version(1, 0, 0))
        XCTAssertEqual(SchemaV1.models.count, 4)
    }

    func testConnectionStateFollowsLatestProbe() throws {
        let context = try makeContext()
        let server = Server(name: "probe", host: "10.0.0.1", username: "root")
        context.insert(server)

        XCTAssertEqual(server.connectionState, .unknown)

        server.lastProbeAt = Date()
        XCTAssertEqual(server.connectionState, .offline)
        XCTAssertEqual(server.latencyText, "不可达")

        server.lastLatencyMs = 42
        XCTAssertEqual(server.connectionState, .online)
        XCTAssertEqual(server.latencyText, "42 ms")

        server.lastLatencyMs = 500
        XCTAssertEqual(server.connectionState, .warning)
    }

    @MainActor
    func testBootstrapCreatesDefaultGroupsOnlyOnce() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let store = AppStore()

        store.bootstrap(context: context)
        store.bootstrap(context: context)

        let groups = try context.fetch(FetchDescriptor<ServerGroup>())
        XCTAssertEqual(groups.count, 4)
        XCTAssertEqual(
            Set(groups.map(\.name)),
            Set(["生产环境", "测试环境", "开发环境", "基础设施"])
        )
        XCTAssertEqual(groups.first { $0.name == "生产环境" }?.sortIndex, 0)
    }

    @MainActor
    func testCreateGroupReusesExistingNameAndAppendsSortIndex() throws {
        let container = try Persistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let store = AppStore()

        let first = try XCTUnwrap(store.createGroup(named: "  自建机房  ", context: context))
        try context.save()

        let duplicate = try XCTUnwrap(store.createGroup(named: "自建机房", context: context))
        XCTAssertEqual(first.id, duplicate.id)

        let second = try XCTUnwrap(store.createGroup(named: "边缘节点", context: context))
        try context.save()

        XCTAssertEqual(second.sortIndex, first.sortIndex + 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ServerGroup>()).count, 2)

        XCTAssertNil(store.createGroup(named: "   ", context: context))
    }

    @MainActor
    func testTagFilterAndGroupFilterAreMutuallyExclusive() throws {
        let store = AppStore()

        store.selectGroup(.ungrouped)
        store.toggleTag("数据库")

        XCTAssertEqual(store.tagFilter, "数据库")
        XCTAssertEqual(store.groupSelection, .all)

        // 再次点击同一标签取消过滤
        store.toggleTag("数据库")
        XCTAssertNil(store.tagFilter)

        store.selectGroup(.ungrouped)
        store.toggleTag("K8s")
        store.selectGroup(.ungrouped)

        XCTAssertNil(store.tagFilter)
        XCTAssertEqual(store.groupSelection, .ungrouped)
    }

    @MainActor
    func testClearFiltersResetsAllConditions() throws {
        let store = AppStore()
        store.searchText = "api"
        store.quickFilter = .recent
        store.groupSelection = .ungrouped
        store.tagFilter = "数据库"

        store.clearFilters()

        XCTAssertEqual(store.searchText, "")
        XCTAssertEqual(store.quickFilter, .all)
        XCTAssertEqual(store.groupSelection, .all)
        XCTAssertNil(store.tagFilter)
    }
}
