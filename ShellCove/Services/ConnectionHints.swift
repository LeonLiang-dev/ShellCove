import Foundation

/// 把 ssh 的常见英文错误翻译成可操作的中文提示（PRD FR-05）。
enum ConnectionHints {
    static func message(for output: String, authMode: AuthMode) -> String? {
        let text = output.lowercased()

        if text.contains("permission denied") {
            switch authMode {
            case .keyAgent:
                return "认证被拒绝。请确认 ssh-agent 已加载对应密钥，或填写正确的私钥路径。"
            case .password:
                return "认证被拒绝。请检查已保存的密码。"
            }
        }

        if text.contains("no such identity") || text.contains("no such file or directory") {
            return "私钥文件不存在或不可读，请检查私钥路径。"
        }

        if text.contains("host key verification failed") {
            return "主机指纹校验失败。请核对指纹后手动更新 known_hosts。"
        }

        if text.contains("could not resolve hostname") {
            return "无法解析主机名，请检查主机地址或 DNS。"
        }

        if text.contains("connection refused") {
            return "目标端口未开放或被拒绝，请检查端口与服务状态。"
        }

        if text.contains("connection timed out") || text.contains("operation timed out") {
            return "连接超时，请检查网络、防火墙或端口。"
        }

        return nil
    }
}
