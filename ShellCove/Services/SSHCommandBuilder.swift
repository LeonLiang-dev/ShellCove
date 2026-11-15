import Foundation

/// 一次 ssh 进程的启动参数。用数组而不是拼接字符串，避免参数注入与转义问题。
struct SSHLaunchConfiguration: Sendable {
    let executable: String
    let arguments: [String]
    let environment: [String: String]
}

enum SSHCommandBuilder {
    static let sshExecutable = "/usr/bin/ssh"

    /// 构造系统 ssh 的 argv 与环境变量（PRD 7.3）。
    ///
    /// connectTimeout 是 FR-07 的连接超时：只限制 TCP 建连阶段，
    /// 不影响密钥确认等交互流程。
    static func launchConfiguration(
        for server: Server,
        askPassPath: String?,
        connectTimeout: Int = 10
    ) -> SSHLaunchConfiguration {
        var arguments = [sshExecutable, "-tt", "-p", String(server.port)]
        arguments.append(contentsOf: ["-o", "ConnectTimeout=\(connectTimeout)"])

        if server.authMode == .keyAgent,
           let key = server.privateKeyPath,
           !key.isEmpty {
            // 直接 execve 不会展开 ~，这里先转成绝对路径。
            arguments.append(contentsOf: ["-i", (key as NSString).expandingTildeInPath])
        }

        arguments.append("\(server.username)@\(server.host)")

        var environment: [String: String] = [
            "TERM": "xterm-256color",
            "LANG": "en_US.UTF-8"
        ]

        if server.authMode == .password, let askPassPath {
            environment["SSH_ASKPASS"] = askPassPath
            environment["SSH_ASKPASS_REQUIRE"] = "force"
            environment["SHELLCOVE_ACCOUNT"] = server.id.uuidString
        }

        return SSHLaunchConfiguration(
            executable: sshExecutable,
            arguments: arguments,
            environment: environment
        )
    }
}

/// 生成 askpass 脚本。脚本本身不含密码，只按服务器 ID 从 Keychain 取。
enum AskPassInstaller {
    static func ensureScript() throws -> String {
        let directory = try FileManager.default
            .url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            .appendingPathComponent("ShellCove/askpass", isDirectory: true)

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        let script = directory.appendingPathComponent("askpass.sh")
        let content = """
        #!/bin/sh
        exec /usr/bin/security find-generic-password -s "\(KeychainService.serviceName)" -a "$SHELLCOVE_ACCOUNT" -w
        """

        try content.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: script.path
        )
        return script.path
    }
}
