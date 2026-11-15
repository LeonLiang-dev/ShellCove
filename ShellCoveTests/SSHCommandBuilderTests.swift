import XCTest

@testable import ShellCove

final class SSHCommandBuilderTests: XCTestCase {
    func testKeyAuthUsesPortAndPrivateKey() {
        let server = Server(
            name: "api-prod-01",
            host: "10.20.1.11",
            port: 2222,
            username: "deploy",
            authMode: .keyAgent,
            privateKeyPath: "/Users/leon/.ssh/id_ed25519"
        )

        let configuration = SSHCommandBuilder.launchConfiguration(for: server, askPassPath: nil)

        XCTAssertEqual(configuration.executable, "/usr/bin/ssh")
        XCTAssertEqual(
            Array(configuration.arguments.dropFirst()),
            [
                "-tt", "-p", "2222", "-o", "ConnectTimeout=10",
                "-i", "/Users/leon/.ssh/id_ed25519", "deploy@10.20.1.11"
            ]
        )
        XCTAssertEqual(configuration.environment["TERM"], "xterm-256color")
        XCTAssertNil(configuration.environment["SSH_ASKPASS"])
    }

    func testConnectTimeoutIsPassedAsSSHOption() {
        let server = Server(name: "api", host: "api.example.com", username: "deploy")

        let configuration = SSHCommandBuilder.launchConfiguration(
            for: server,
            askPassPath: nil,
            connectTimeout: 15
        )

        XCTAssertEqual(
            Array(configuration.arguments.dropFirst()),
            ["-tt", "-p", "22", "-o", "ConnectTimeout=15", "deploy@api.example.com"]
        )
    }

    func testConnectTimeoutBoundaries() {
        let server = Server(name: "api", host: "api.example.com", username: "deploy")

        for seconds in [5, 60] {
            let configuration = SSHCommandBuilder.launchConfiguration(
                for: server,
                askPassPath: nil,
                connectTimeout: seconds
            )
            XCTAssertTrue(configuration.arguments.contains("ConnectTimeout=\(seconds)"))
        }
    }

    func testKeyAuthWithoutKeyPathLetsSSHDecide() {
        let server = Server(name: "api", host: "api.example.com", username: "deploy")

        let configuration = SSHCommandBuilder.launchConfiguration(for: server, askPassPath: nil)

        XCTAssertFalse(configuration.arguments.contains("-i"))
        XCTAssertEqual(configuration.arguments.last, "deploy@api.example.com")
    }

    func testTildePrivateKeyIsExpandedForExec() {
        let server = Server(
            name: "api",
            host: "api.example.com",
            username: "deploy",
            privateKeyPath: "~/.ssh/id_ed25519"
        )

        let configuration = SSHCommandBuilder.launchConfiguration(for: server, askPassPath: nil)
        let expected = NSHomeDirectory() + "/.ssh/id_ed25519"

        XCTAssertEqual(configuration.arguments.last, "deploy@api.example.com")
        XCTAssertTrue(configuration.arguments.contains(expected))
        XCTAssertEqual(server.sshCommand, "ssh -p 22 -i \(expected) deploy@api.example.com")
    }

    func testConnectionHintsForAuthFailures() {
        let keyHint = ConnectionHints.message(
            for: "deploy@10.0.0.1: Permission denied (publickey).",
            authMode: .keyAgent
        )
        XCTAssertTrue(keyHint?.contains("ssh-agent") == true)

        let passwordHint = ConnectionHints.message(
            for: "root@10.0.0.1: Permission denied (password).",
            authMode: .password
        )
        XCTAssertTrue(passwordHint?.contains("密码") == true)
    }

    func testConnectionHintsForCommonNetworkErrors() {
        XCTAssertNotNil(
            ConnectionHints.message(for: "Host key verification failed.", authMode: .keyAgent)
        )
        XCTAssertNotNil(
            ConnectionHints.message(for: "ssh: Could not resolve hostname api.", authMode: .keyAgent)
        )
        XCTAssertNotNil(
            ConnectionHints.message(for: "ssh: connect to host 10.0.0.1 port 22: Connection refused", authMode: .keyAgent)
        )
        XCTAssertNil(
            ConnectionHints.message(for: "deploy@api-prod-01:~$", authMode: .keyAgent)
        )
    }

    func testPasswordAuthUsesAskPassEnvironment() {
        let server = Server(
            name: "legacy-vps",
            host: "10.0.0.9",
            port: 22,
            username: "root",
            authMode: .password,
            privateKeyPath: "/should/be/ignored"
        )

        let configuration = SSHCommandBuilder.launchConfiguration(
            for: server,
            askPassPath: "/tmp/askpass.sh"
        )

        XCTAssertEqual(configuration.environment["SSH_ASKPASS"], "/tmp/askpass.sh")
        XCTAssertEqual(configuration.environment["SSH_ASKPASS_REQUIRE"], "force")
        XCTAssertEqual(configuration.environment["SHELLCOVE_ACCOUNT"], server.id.uuidString)
        XCTAssertFalse(configuration.arguments.contains("-i"))
        XCTAssertEqual(configuration.arguments.last, "root@10.0.0.9")
    }

    func testPasswordAuthWithoutAskPassFallsBackToTerminalPrompt() {
        let server = Server(
            name: "legacy-vps",
            host: "10.0.0.9",
            username: "root",
            authMode: .password
        )

        let configuration = SSHCommandBuilder.launchConfiguration(for: server, askPassPath: nil)

        XCTAssertNil(configuration.environment["SSH_ASKPASS"])
        XCTAssertNil(configuration.environment["SSH_ASKPASS_REQUIRE"])
    }

    func testAskPassScriptContainsNoSecret() throws {
        let path = try AskPassInstaller.ensureScript()
        let content = try String(contentsOfFile: path, encoding: .utf8)
        let attributes = try FileManager.default.attributesOfItem(atPath: path)

        XCTAssertTrue(content.contains("/usr/bin/security"))
        XCTAssertTrue(content.contains("SHELLCOVE_ACCOUNT"))
        XCTAssertFalse(content.contains("password="))
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o700)
    }

    func testPTYSessionRunsProcessAndReportsExitCode() throws {
        let probe = PTYProbe()

        let configuration = SSHLaunchConfiguration(
            executable: "/bin/echo",
            arguments: ["/bin/echo", "shellcove"],
            environment: ["TERM": "xterm-256color"]
        )

        let session = PTYSession(
            configuration: configuration,
            cols: 80,
            rows: 24,
            onOutput: { probe.append($0) },
            onExit: { probe.finish($0) }
        )

        XCTAssertNotNil(session)
        wait(for: [probe.finished], timeout: 5)

        XCTAssertEqual(probe.exitCode, 0)
        XCTAssertTrue(probe.text.contains("shellcove"))
    }
}

/// 跨线程收集 PTY 输出，避免测试里直接共享可变状态。
private final class PTYProbe: @unchecked Sendable {
    let finished = XCTestExpectation(description: "pty exit")

    private let lock = NSLock()
    private var storage = Data()
    private(set) var exitCode: Int32?

    func append(_ data: ArraySlice<UInt8>) {
        lock.lock()
        storage.append(contentsOf: data)
        lock.unlock()
    }

    func finish(_ code: Int32?) {
        lock.lock()
        exitCode = code
        lock.unlock()
        finished.fulfill()
    }

    var text: String {
        lock.lock()
        defer { lock.unlock() }
        return String(decoding: storage, as: UTF8.self)
    }
}
