//
//  TerminalColors.swift
//  TYLER'S TERMINAL
//

import SwiftUI

struct TerminalColors {
    static let background = Color.black
    static let backgroundSecondary = Color(hex: "#0A0A0A")
    static let backgroundTertiary = Color(hex: "#111111")
    
    static let primary = Color(hex: "#FF6B00")
    static let primaryLight = Color(hex: "#FF8533")
    static let primaryDark = Color(hex: "#CC5500")
    
    static let secondary = Color(hex: "#00D4AA")
    static let secondaryLight = Color(hex: "#33E0BF")
    static let secondaryDark = Color(hex: "#00A885")
    
    static let positive = Color(hex: "#00D4AA")
    static let negative = Color(hex: "#FF3B30")
    static let warning = Color(hex: "#FF9500")
    static let alert = Color(hex: "#FF3B30")
    
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "#888888")
    static let textTertiary = Color(hex: "#555555")
    static let textMuted = Color(hex: "#333333")
    
    static let border = Color(hex: "#333333")
    static let borderLight = Color(hex: "#444444")
    static let borderHighlight = Color(hex: "#FF6B00")
    
    static let statusOnline = Color(hex: "#00D4AA")
    static let statusOffline = Color(hex: "#FF3B30")
    static let statusPending = Color(hex: "#FF9500")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    var uiColor: UIColor {
        UIColor(self)
    }
}

struct TerminalFonts {
    static let header = Font.system(.title, design: .monospaced).weight(.bold)
    static let header2 = Font.system(.title2, design: .monospaced).weight(.semibold)
    static let header3 = Font.system(.title3, design: .monospaced).weight(.medium)
    
    static let body = Font.system(.body, design: .default)
    static let bodyMono = Font.system(.body, design: .monospaced)
    
    static let caption = Font.system(.caption, design: .monospaced)
    static let caption2 = Font.system(.caption2, design: .monospaced)
    
    static let ticker = Font.system(.callout, design: .monospaced).weight(.semibold)
    static let timestamp = Font.system(.caption, design: .monospaced)
    static let numeric = Font.system(.body, design: .monospaced).weight(.medium)
}
