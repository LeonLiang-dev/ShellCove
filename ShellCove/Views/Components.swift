import SwiftUI

/// 连接状态。M1 尚无探活能力，统一显示为「未知」；M4 接入探活后填充真实状态。
enum ConnectionState {
    case unknown
    case online
    case warning
    case offline

    var color: Color {
        switch self {
        case .unknown: Color.secondary.opacity(0.45)
        case .online: Color(red: 0.204, green: 0.780, blue: 0.349)
        case .warning: Theme.staging
        case .offline: Color.secondary.opacity(0.3)
        }
    }

    var label: String {
        switch self {
        case .unknown: "未检测"
        case .online: "在线"
        case .warning: "告警"
        case .offline: "离线"
        }
    }
}

struct StatusDot: View {
    var state: ConnectionState = .unknown
    var size: CGFloat = 6

    var body: some View {
        Circle()
            .fill(state.color)
            .frame(width: size, height: size)
    }
}

struct EnvPill: View {
    let environment: ServerEnvironment

    var body: some View {
        Text(environment.displayName)
            .font(.system(size: 9.5, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 1.5)
            .foregroundStyle(environment.tint)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(environment.tint.opacity(0.13))
            )
    }
}

struct IconTile: View {
    let systemName: String
    var size: CGFloat = 27

    var body: some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(Theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 7).strokeBorder(Theme.hairline)
            )
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: size * 0.46, weight: .medium))
                    .foregroundStyle(.secondary)
            )
            .frame(width: size, height: size)
    }
}

struct ToastView: View {
    let text: String?

    var body: some View {
        if let text {
            HStack(spacing: 7) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(Theme.accent)
                Text(text)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.hairline))
            .shadow(color: .black.opacity(0.14), radius: 14, y: 5)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }
}

struct BrandMark: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.306, green: 0.878, blue: 0.808),
                        Color(red: 0.122, green: 0.561, blue: 0.620),
                        Color(red: 0.086, green: 0.384, blue: 0.478)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "terminal")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(Color(red: 0.016, green: 0.129, blue: 0.121))
            )
            .frame(width: 19, height: 19)
            .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
    }
}
