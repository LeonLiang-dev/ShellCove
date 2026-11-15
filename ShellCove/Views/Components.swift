import SwiftUI

/// 连接状态。由最近一次手动探活的结果推导，未探活时保持「未知」。
enum ConnectionState: Equatable {
    case unknown
    case online
    case warning
    case offline

    var color: Color {
        switch self {
        case .unknown: Color.secondary.opacity(0.45)
        case .online: Theme.success
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

extension Server {
    /// 最近一次手动探活的结果：未探活为未知，探活失败为离线。
    var connectionState: ConnectionState {
        guard lastProbeAt != nil else { return .unknown }
        guard let latency = lastLatencyMs else { return .offline }
        return latency > 300 ? .warning : .online
    }

    var latencyText: String {
        guard lastProbeAt != nil else { return "未检测" }
        guard let latency = lastLatencyMs else { return "不可达" }
        return "\(latency) ms"
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

/// ShellCove 品牌标记：贝壳轮廓 + `>_` + 青色波浪。
/// 直接按品牌 SVG 的坐标绘制，保证任意尺寸下都清晰。
struct BrandMark: View {
    var size: CGFloat = 19
    var monochrome = false

    var body: some View {
        Canvas { context, canvasSize in
            let scale = min(canvasSize.width / 274, canvasSize.height / 326)
            let offsetX = (canvasSize.width - 274 * scale) / 2 - 120 * scale
            let offsetY = (canvasSize.height - 326 * scale) / 2 - 103 * scale

            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: offsetX + x * scale, y: offsetY + y * scale)
            }

            let ink = monochrome ? Color.white : Color.primary
            let waveColor = monochrome ? Color.white.opacity(0.65) : Theme.accent
            let stroke = StrokeStyle(
                lineWidth: 19 * scale,
                lineCap: .round,
                lineJoin: .round
            )

            var shell = Path()
            shell.move(to: point(381, 107))
            shell.addLine(to: point(203, 107))
            shell.addCurve(to: point(124, 186), control1: point(158, 107), control2: point(124, 141))
            shell.addLine(to: point(124, 317))
            shell.addCurve(to: point(142, 371), control1: point(124, 338), control2: point(130, 357))
            shell.addLine(to: point(188, 371))
            shell.addCurve(to: point(166, 317), control1: point(174, 357), control2: point(166, 343))
            shell.addLine(to: point(166, 186))
            shell.addCurve(to: point(203, 150), control1: point(166, 165), control2: point(181, 150))
            shell.addLine(to: point(381, 150))
            shell.addCurve(to: point(390, 141), control1: point(386, 150), control2: point(390, 146))
            shell.addLine(to: point(390, 116))
            shell.addCurve(to: point(381, 107), control1: point(390, 111), control2: point(386, 107))
            shell.closeSubpath()
            context.fill(shell, with: .color(ink))

            var chevron = Path()
            chevron.move(to: point(237, 230))
            chevron.addLine(to: point(263, 251))
            chevron.addLine(to: point(237, 272))
            context.stroke(chevron, with: .color(ink), style: stroke)

            var underscore = Path()
            underscore.move(to: point(283, 275))
            underscore.addLine(to: point(308, 275))
            context.stroke(underscore, with: .color(ink), style: stroke)

            var wave = Path()
            wave.move(to: point(143, 379))
            wave.addCurve(to: point(273, 367), control1: point(189, 400), control2: point(232, 383))
            wave.addCurve(to: point(389, 363), control1: point(315, 351), control2: point(352, 348))
            wave.addLine(to: point(389, 400))
            wave.addCurve(to: point(268, 411), control1: point(340, 385), control2: point(310, 396))
            wave.addCurve(to: point(143, 379), control1: point(215, 428), control2: point(176, 416))
            wave.closeSubpath()
            context.fill(wave, with: .color(waveColor))
        }
        .frame(width: size, height: size * 326 / 274)
        .accessibilityHidden(true)
    }
}
