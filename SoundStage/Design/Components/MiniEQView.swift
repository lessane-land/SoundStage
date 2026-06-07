import SwiftUI

/// Static frequency-shape preview for the preset detail sheet. The curve
/// responds to the Room Size / Reverb Depth / Stereo Width sliders, drawn as a
/// gradient line over a soft fill, above a row of baseline ticks.
struct MiniEQView: View {
    let preset: Preset
    var room: Double
    var reverb: Double
    var width: Double

    var body: some View {
        Canvas { context, size in
            let sx = size.width / 240
            let sy = size.height / 100

            func scaled(_ x: Double, _ y: Double) -> CGPoint {
                CGPoint(x: x * sx, y: y * sy)
            }

            // Baseline ticks.
            var ticks = Path()
            for i in 0...8 {
                let x = Double(i) * 240 / 8
                ticks.move(to: scaled(x, 94))
                ticks.addLine(to: scaled(x, 100))
            }
            context.stroke(ticks, with: .color(.white.opacity(0.18)), lineWidth: 1)

            // Curve (matches the design's MiniEQ path).
            let lift = 0.2 + reverb * 0.5
            let mid = 0.3 + room * 0.5
            let tail = 0.15 + width * 0.45
            func y(_ v: Double) -> Double { 100 - v * 100 * 0.82 - 8 }

            var curve = Path()
            curve.move(to: scaled(0, y(0.12)))
            curve.addCurve(
                to: scaled(240 * 0.42, y(mid)),
                control1: scaled(240 * 0.16, y(lift)),
                control2: scaled(240 * 0.28, y(mid))
            )
            // First smooth segment (reflected control point).
            curve.addCurve(
                to: scaled(240 * 0.74, y(tail + 0.15)),
                control1: scaled(240 * 0.56, y(mid)),
                control2: scaled(240 * 0.62, y(0.62))
            )
            // Second smooth segment.
            curve.addCurve(
                to: scaled(240, y(tail * 0.7)),
                control1: scaled(240 * 0.86, 2 * y(tail + 0.15) - y(0.62)),
                control2: scaled(240 * 0.92, y(tail))
            )

            // Soft fill under the curve.
            var fill = curve
            fill.addLine(to: scaled(240, 100))
            fill.addLine(to: scaled(0, 100))
            fill.closeSubpath()
            context.fill(
                fill,
                with: .linearGradient(
                    Gradient(colors: [preset.toColor.opacity(0.28), preset.fromColor.opacity(0)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )

            context.stroke(
                curve,
                with: .linearGradient(
                    Gradient(colors: [preset.fromColor, preset.toColor]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: 0)
                ),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
            )
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    MiniEQView(preset: PresetStore().presets[2], room: 0.62, reverb: 0.48, width: 0.7)
        .frame(height: 72)
        .padding()
        .background(DesignTokens.Palette.cardFill)
}
