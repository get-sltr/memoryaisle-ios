import SwiftUI

// MARK: - Named Colors

extension Color {
    // Brand anchor
    nonisolated static let violet = Color(hex: 0xA78BFA)
    nonisolated static let violetDeep = Color(hex: 0x7C3AED)
    nonisolated static let violetMid = Color(hex: 0x8B5CF6)
    nonisolated static let lavender = Color(hex: 0xC4B5FD)
    nonisolated static let indigoBlack = Color(hex: 0x0A0914)

    // Pantry — emerald
    nonisolated static let emerald = Color(hex: 0x10B981)
    nonisolated static let emeraldDeep = Color(hex: 0x047857)
    nonisolated static let emeraldMid = Color(hex: 0x059669)
    nonisolated static let emeraldSoft = Color(hex: 0x6EE7B7)

    // Recipes — amber
    nonisolated static let amber = Color(hex: 0xF59E0B)
    nonisolated static let amberDeep = Color(hex: 0xB45309)
    nonisolated static let amberMid = Color(hex: 0xD97706)
    nonisolated static let amberSoft = Color(hex: 0xFCD34D)

    // Scanner — cyan
    nonisolated static let cyan = Color(hex: 0x06B6D4)
    nonisolated static let cyanDeep = Color(hex: 0x0E7490)
    nonisolated static let cyanMid = Color(hex: 0x0891B2)
    nonisolated static let cyanSoft = Color(hex: 0x67E8F9)

    // Grocery — sky
    nonisolated static let sky = Color(hex: 0x0EA5E9)
    nonisolated static let skyDeep = Color(hex: 0x0369A1)
    nonisolated static let skyMid = Color(hex: 0x0284C7)
    nonisolated static let skySoft = Color(hex: 0x7DD3FC)

    // Calendar — rose
    nonisolated static let rose = Color(hex: 0xF472B6)
    nonisolated static let roseDeep = Color(hex: 0xBE185D)
    nonisolated static let roseMid = Color(hex: 0xDB2777)
    nonisolated static let roseSoft = Color(hex: 0xFBCFE8)

    // Progress — lime
    nonisolated static let lime = Color(hex: 0x84CC16)
    nonisolated static let limeDeep = Color(hex: 0x4D7C0F)
    nonisolated static let limeMid = Color(hex: 0x65A30D)
    nonisolated static let limeSoft = Color(hex: 0xBEF264)
}

// MARK: - Hex Initializer

extension Color {
    nonisolated init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
