import AppKit
import SwiftUI

/// 颜色与尺寸的唯一来源。所有界面元素从这里取色，避免散落的十六进制值。
enum Theme {
    static let accent = adaptive(dark: 0x3E_CFBF, light: 0x0F_9F92)
    static let production = adaptive(dark: 0xFF_6B5E, light: 0xE0_4A3D)
    static let staging = adaptive(dark: 0xFF_B340, light: 0xD9_8709)
    static let development = adaptive(dark: 0x58_A6FF, light: 0x2D_7FDB)
    static let infrastructure = adaptive(dark: 0xA7_8BFA, light: 0x7C_5CE0)

    static let hairline = Color.primary.opacity(0.09)
    static let surface = Color.primary.opacity(0.045)
    static let surfaceStrong = Color.primary.opacity(0.072)
    static let sidebar = Color.primary.opacity(0.026)

    static let leftColumnWidth: CGFloat = 318
    static let titleBarHeight: CGFloat = 52

    /// 深色/浅色下取不同色值，避免浅色模式对比度不足。
    static func adaptive(dark: UInt32, light: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(rgbHex: isDark ? dark : light)
        })
    }
}

extension NSColor {
    convenience init(rgbHex: UInt32) {
        self.init(
            srgbRed: CGFloat((rgbHex >> 16) & 0xFF) / 255,
            green: CGFloat((rgbHex >> 8) & 0xFF) / 255,
            blue: CGFloat(rgbHex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension ServerEnvironment {
    var tint: Color {
        switch self {
        case .production: Theme.production
        case .staging: Theme.staging
        case .development: Theme.development
        case .infrastructure: Theme.infrastructure
        }
    }
}
