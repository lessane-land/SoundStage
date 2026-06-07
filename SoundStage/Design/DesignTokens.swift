import SwiftUI

/// Central source of truth for colors, typography, spacing and corner radii.
///
/// Everything visual in SoundStage pulls from here so the dark, glassmorphic
/// look stays consistent across screens. Values mirror the spec in CLAUDE.md.
enum DesignTokens {

    // MARK: Colors

    enum Palette {
        /// #0A0A0F — the near-black app background.
        static let backgroundPrimary = Color(hex: 0x0A0A0F)
        /// #6C5CE7 — primary brand accent (violet).
        static let accent = Color(hex: 0x6C5CE7)
        /// #FDCB6E — amber, used to mark the active / selected state.
        static let active = Color(hex: 0xFDCB6E)
        /// #FFFFFF — primary text.
        static let textPrimary = Color.white
        /// #8A8A9A — secondary / muted text.
        static let textSecondary = Color(hex: 0x8A8A9A)
        /// rgba(255,255,255,0.06) — frosted card surface.
        static let cardSurface = Color.white.opacity(0.06)
        /// Hairline stroke that gives glass cards their edge.
        static let cardStroke = Color.white.opacity(0.10)
    }

    // MARK: Spacing (8pt grid)

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: Corner radii

    enum Radius {
        static let control: CGFloat = 12
        static let card: CGFloat = 20
        static let sheet: CGFloat = 28
    }

    // MARK: Typography

    enum Typography {
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
        static let title = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 16, weight: .regular, design: .rounded)
        static let caption = Font.system(size: 13, weight: .medium, design: .rounded)
    }
}

extension Color {
    /// Build a `Color` from a 24-bit RGB literal, e.g. `Color(hex: 0x6C5CE7)`.
    init(hex: UInt32, opacity: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
