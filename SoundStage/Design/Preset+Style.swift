import SwiftUI

/// Visual styling derived from a `Preset`'s gradient identity.
///
/// Kept in the Design layer so the `Preset` data model stays free of SwiftUI.
extension Preset {

    var fromColor: Color { Color(hex: gradientFromHex) }
    var toColor: Color { Color(hex: gradientToHex) }

    /// The preset's signature gradient. `angle` is in degrees (135° default,
    /// matching the design's `linear-gradient(135deg, from, to)`).
    func gradient(angle: Double = 135) -> LinearGradient {
        let (start, end) = Self.endpoints(forAngle: angle)
        return LinearGradient(colors: [fromColor, toColor], startPoint: start, endPoint: end)
    }

    /// A translucent version of the gradient.
    func gradient(angle: Double = 135, opacity: Double) -> LinearGradient {
        let (start, end) = Self.endpoints(forAngle: angle)
        return LinearGradient(
            colors: [fromColor.opacity(opacity), toColor.opacity(opacity)],
            startPoint: start,
            endPoint: end
        )
    }

    /// Color at a horizontal fraction of the gradient (used per waveform bar).
    func color(atFraction fraction: Double) -> Color {
        Color.lerp(gradientFromHex, gradientToHex, fraction)
    }

    /// Maps a CSS-style gradient angle to SwiftUI unit points.
    private static func endpoints(forAngle degrees: Double) -> (UnitPoint, UnitPoint) {
        let radians = degrees * .pi / 180
        let dx = cos(radians), dy = sin(radians)
        let start = UnitPoint(x: 0.5 - dx / 2, y: 0.5 + dy / 2)
        let end = UnitPoint(x: 0.5 + dx / 2, y: 0.5 - dy / 2)
        return (start, end)
    }
}
