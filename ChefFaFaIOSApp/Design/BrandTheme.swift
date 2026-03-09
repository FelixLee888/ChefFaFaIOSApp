import SwiftUI

enum BrandTheme {
    static let background = Color(red: 1.000, green: 0.980, blue: 0.949)
    static let paper = Color(red: 1.000, green: 0.992, blue: 0.973)
    static let ink = Color(red: 0.122, green: 0.106, blue: 0.086)
    static let muted = Color(red: 0.427, green: 0.384, blue: 0.333)
    static let accent = Color(red: 0.698, green: 0.302, blue: 0.157)
    static let accentSoft = Color(red: 0.969, green: 0.875, blue: 0.820)
    static let brand = Color(red: 0.059, green: 0.435, blue: 0.404)
    static let brandSoft = Color(red: 0.847, green: 0.949, blue: 0.933)
    static let line = Color(red: 0.918, green: 0.855, blue: 0.773)

    static let heroGradient = LinearGradient(
        colors: [
            Color(red: 1.000, green: 0.937, blue: 0.882),
            Color(red: 1.000, green: 0.984, blue: 0.965),
            Color(red: 0.910, green: 0.973, blue: 0.953)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let pageGradient = LinearGradient(
        colors: [background, Color.white.opacity(0.9)],
        startPoint: .top,
        endPoint: .bottom
    )
}

