import Foundation

/// 服务器所属环境。环境必须唯一，用于连接前的风险提示。
enum ServerEnvironment: String, Codable, CaseIterable, Identifiable, Sendable {
    case production = "prod"
    case staging = "stage"
    case development = "dev"
    case infrastructure = "infra"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .production: "生产"
        case .staging: "测试"
        case .development: "开发"
        case .infrastructure: "基础设施"
        }
    }

    /// 默认分组的名称。环境与默认分组一一对应。
    var defaultGroupName: String {
        switch self {
        case .production: "生产环境"
        case .staging: "测试环境"
        case .development: "开发环境"
        case .infrastructure: "基础设施"
        }
    }
}

/// 认证方式。密码只存系统 Keychain，应用数据库不保存任何凭据。
enum AuthMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case keyAgent = "keyAgent"
    case password = "password"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .keyAgent: "SSH Key / agent"
        case .password: "密码"
        }
    }

    var shortName: String {
        switch self {
        case .keyAgent: "SSH Key"
        case .password: "密码"
        }
    }
}

/// 一次终端会话的结束方式。
enum SessionEndReason: String, Codable, CaseIterable, Sendable {
    case exited
    case userClosed
    case appQuit
    case interrupted

    var displayName: String {
        switch self {
        case .exited: "正常退出"
        case .userClosed: "用户断开"
        case .appQuit: "应用退出"
        case .interrupted: "异常结束"
        }
    }
}
