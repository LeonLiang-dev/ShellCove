import SwiftUI

/// 外观模式（PRD FR-07）：跟随系统 / 深色 / 浅色。
enum AppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case system
    case dark
    case light

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "跟随系统"
        case .dark: "深色"
        case .light: "浅色"
        }
    }

    /// nil 表示跟随系统，交给 SwiftUI 的 preferredColorScheme 决定。
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .dark: .dark
        case .light: .light
        }
    }
}

/// 设置键集中管理，避免字符串字面量散落各处。
enum SettingsKey {
    static let appearance = "settings.appearance"
    static let terminalFontSize = "settings.terminalFontSize"
    static let connectTimeoutSeconds = "settings.connectTimeoutSeconds"
    static let autoProbeOnDetailOpen = "settings.autoProbeOnDetailOpen"
}

/// 应用设置（PRD FR-07）：外观、终端字号、连接超时、自动探活。
///
/// 全是标量偏好，存 UserDefaults 即可；不进 SwiftData，避免无谓的 schema 迁移。
/// 与 AppStore 相同的 @Observable 注入模式，didSet 写回、init 读入。
@MainActor
@Observable
final class SettingsStore {
    static let defaultFontSize = 12.2
    static let fontSizeRange: ClosedRange<Double> = 11...16
    static let defaultConnectTimeout = 10
    static let connectTimeoutRange: ClosedRange<Int> = 5...60

    var appearance: AppearanceMode {
        didSet { defaults.set(appearance.rawValue, forKey: SettingsKey.appearance) }
    }

    /// 终端字号（11-16），默认 12.2 与既有视觉保持一致（PRD FR-07）。
    var terminalFontSize: Double {
        didSet { defaults.set(terminalFontSize, forKey: SettingsKey.terminalFontSize) }
    }

    /// ssh 连接超时秒数，作为 -o ConnectTimeout=N 传入；只限制 TCP 建连阶段。
    var connectTimeoutSeconds: Int {
        didSet { defaults.set(connectTimeoutSeconds, forKey: SettingsKey.connectTimeoutSeconds) }
    }

    /// 打开详情页时自动探活，默认关闭（PRD FR-07）。
    var autoProbeOnDetailOpen: Bool {
        didSet { defaults.set(autoProbeOnDetailOpen, forKey: SettingsKey.autoProbeOnDetailOpen) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = defaults
            .string(forKey: SettingsKey.appearance)
            .flatMap(AppearanceMode.init(rawValue:)) ?? .system
        let storedFontSize = (defaults.object(forKey: SettingsKey.terminalFontSize) as? NSNumber)?.doubleValue
        terminalFontSize = Self.clamp(storedFontSize ?? Self.defaultFontSize, in: Self.fontSizeRange)
        let storedTimeout = (defaults.object(forKey: SettingsKey.connectTimeoutSeconds) as? NSNumber)?.intValue
        connectTimeoutSeconds = Self.clamp(storedTimeout ?? Self.defaultConnectTimeout, in: Self.connectTimeoutRange)
        autoProbeOnDetailOpen = defaults.bool(forKey: SettingsKey.autoProbeOnDetailOpen)
    }

    private static func clamp<T: Comparable>(_ value: T, in range: ClosedRange<T>) -> T {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
