import SwiftData
import XCTest

@testable import ShellCove

@MainActor
final class MenuBarQuickAccessTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let container = try Persistence.makeContainer(inMemory: true)
        return ModelContext(container)
    }

    private func insertServer(
        named name: String,
        lastConnectedAt: Date?,
        context: ModelContext
    ) throws -> Server {
        let server = Server(name: name, host: "10.0.0.1", username: "deploy")
        server.lastConnectedAt = lastConnectedAt
        context.insert(server)
        try context.save()
        return server
    }

    func testOnlyConnectedServersAppear() throws {
        let context = try makeContext()
        let never = try insertServer(named: "从未连接", lastConnectedAt: nil, context: context)
        let recent = try insertServer(
            named: "昨天连过",
            lastConnectedAt: Date(timeIntervalSinceNow: -86_400),
            context: context
        )

        let result = MenuBarQuickAccess.recentServers([never, recent])
        XCTAssertEqual(result.map(\.name), ["昨天连过"])
    }

    func testRecentsAreSortedByConnectionTime() throws {
        let context = try makeContext()
        let oldest = try insertServer(
            named: "三天前",
            lastConnectedAt: Date(timeIntervalSinceNow: -3 * 86_400),
            context: context
        )
        let newest = try insertServer(named: "刚才", lastConnectedAt: Date(), context: context)
        let middle = try insertServer(
            named: "昨天",
            lastConnectedAt: Date(timeIntervalSinceNow: -86_400),
            context: context
        )

        let result = MenuBarQuickAccess.recentServers([oldest, middle, newest])
        XCTAssertEqual(result.map(\.name), ["刚才", "昨天", "三天前"])
    }

    func testRecentsCapAtFiveEvenWithMoreServers() throws {
        let context = try makeContext()
        var servers: [Server] = []
        for index in 0..<8 {
            servers.append(
                try insertServer(
                    named: "server-\(index)",
                    lastConnectedAt: Date(timeIntervalSinceNow: TimeInterval(-index) * 600),
                    context: context
                )
            )
        }

        let result = MenuBarQuickAccess.recentServers(servers)
        XCTAssertEqual(result.count, 5)
        XCTAssertEqual(result.map(\.name), ["server-0", "server-1", "server-2", "server-3", "server-4"])
    }
}
