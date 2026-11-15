import SwiftData
import XCTest

@testable import ShellCove

@MainActor
final class SSHConfigImporterTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let container = try Persistence.makeContainer(inMemory: true)
        return ModelContext(container)
    }

    // MARK: - parse（纯函数）

    func testParseTypicalBlock() {
        let text = """
        # 常用机器
        Host api
            HostName 10.20.1.11
            User deploy
            Port 2222
            IdentityFile ~/.ssh/id_ed25519
        """
        let hosts = SSHConfigImporter.parse(text: text)

        XCTAssertEqual(hosts, [
            SSHConfigImporter.ParsedHost(
                alias: "api",
                host: "10.20.1.11",
                user: "deploy",
                port: 2222,
                identityFile: "~/.ssh/id_ed25519"
            )
        ])
    }

    func testParseIsCaseInsensitiveAndSupportsEqualsForm() {
        let text = """
        Host=web
          HOSTNAME web.example.com
          USER deploy
          Port=2200
        """
        let hosts = SSHConfigImporter.parse(text: text)

        XCTAssertEqual(hosts.count, 1)
        XCTAssertEqual(hosts[0].alias, "web")
        XCTAssertEqual(hosts[0].host, "web.example.com")
        XCTAssertEqual(hosts[0].user, "deploy")
        XCTAssertEqual(hosts[0].port, 2200)
    }

    func testParseHostNameMissingFallsBackToAlias() {
        let hosts = SSHConfigImporter.parse(text: "Host jumpbox\n  User root\n")
        XCTAssertEqual(hosts, [
            SSHConfigImporter.ParsedHost(
                alias: "jumpbox",
                host: "jumpbox",
                user: "root",
                port: 22,
                identityFile: nil
            )
        ])
    }

    func testParseSkipsWildcardBlocksIncludingDefaults() {
        let text = """
        Host web-* staging?
            User ignored
            Port 2222
        Host *
            ServerAliveInterval 60
            User nobody
        Host real
            User deploy
        """
        let hosts = SSHConfigImporter.parse(text: text)

        XCTAssertEqual(hosts.count, 1)
        XCTAssertEqual(hosts[0].alias, "real")
        XCTAssertEqual(hosts[0].user, "deploy")
        XCTAssertEqual(hosts[0].port, 22)
    }

    func testParseIgnoresIncludeAndTakesFirstAliasAndIdentity() {
        let text = """
        Include ~/.ssh/work.conf
        Host web web2 web3
            HostName web.example.com
            User deploy
            IdentityFile ~/.ssh/a
            IdentityFile ~/.ssh/b
        """
        let hosts = SSHConfigImporter.parse(text: text)

        XCTAssertEqual(hosts.count, 1)
        XCTAssertEqual(hosts[0].alias, "web")
        XCTAssertEqual(hosts[0].identityFile, "~/.ssh/a")
    }

    func testParseInvalidPortKeepsDefault() {
        let hosts = SSHConfigImporter.parse(text: "Host db\n  Port notanumber\n")
        XCTAssertEqual(hosts.count, 1)
        XCTAssertEqual(hosts[0].port, 22)
    }

    func testParseEmptyOrCommentOnlyTextYieldsNothing() {
        XCTAssertEqual(SSHConfigImporter.parse(text: ""), [])
        XCTAssertEqual(SSHConfigImporter.parse(text: "# 只有注释\n\n   \n"), [])
    }

    // MARK: - 文件读取

    func testParseFileMissingPathThrowsFileNotFound() {
        let url = URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)/config")
        XCTAssertThrowsError(try SSHConfigImporter.parseFile(at: url)) { error in
            XCTAssertEqual(
                error as? SSHConfigImporter.ImportError,
                .fileNotFound
            )
        }
    }

    // MARK: - makePlan 判重

    func testMakePlanSkipsExistingAndInFileDuplicates() throws {
        let context = try makeContext()
        let existing = Server(
            name: "已有机器",
            host: "10.20.1.11",
            port: 2222,
            username: "deploy"
        )
        context.insert(existing)

        let parsed = [
            SSHConfigImporter.ParsedHost(alias: "api", host: "10.20.1.11", user: "deploy", port: 2222, identityFile: nil),
            // 文件内重复（同三元组）
            SSHConfigImporter.ParsedHost(alias: "api-copy", host: "10.20.1.11", user: "deploy", port: 2222, identityFile: nil),
            // 新机器
            SSHConfigImporter.ParsedHost(alias: "web", host: "web.example.com", user: "deploy", port: 22, identityFile: nil)
        ]

        let plan = SSHConfigImporter.makePlan(hosts: parsed, existingServers: [existing])
        XCTAssertEqual(plan.new.map(\.alias), ["web"])
        XCTAssertEqual(plan.skipped, 2)
    }

    // MARK: - apply 落库

    func testApplyInsertsServersWithExpectedDefaults() throws {
        let context = try makeContext()
        let parsed = [
            SSHConfigImporter.ParsedHost(
                alias: "api",
                host: "10.20.1.11",
                user: "deploy",
                port: 2222,
                identityFile: "~/.ssh/id_ed25519"
            ),
            SSHConfigImporter.ParsedHost(alias: "web", host: "web.example.com", user: "deploy", port: 22, identityFile: nil)
        ]

        let count = try SSHConfigImporter.apply(parsed, context: context)
        XCTAssertEqual(count, 2)

        let servers = try context.fetch(FetchDescriptor<Server>()).sorted { $0.name < $1.name }
        XCTAssertEqual(servers.count, 2)

        let api = try XCTUnwrap(servers.first { $0.name == "api" })
        XCTAssertEqual(api.host, "10.20.1.11")
        XCTAssertEqual(api.port, 2222)
        XCTAssertEqual(api.username, "deploy")
        XCTAssertEqual(api.privateKeyPath, "~/.ssh/id_ed25519")
        XCTAssertEqual(api.authMode, .keyAgent)
        XCTAssertEqual(api.environment, .development)
        XCTAssertNil(api.group, "导入的服务器保持未分组，由用户显式整理")
    }
}
