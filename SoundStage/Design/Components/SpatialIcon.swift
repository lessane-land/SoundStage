import SwiftUI

/// The small spatial-audio glyph used in the preset pill: a center ring with
/// radiating ticks. Drawn so it matches the design's custom icon rather than a
/// near-equivalent SF Symbol.
struct SpatialIcon: View {
    var color: Color = .white
    var lineWidth: CGFloat = 1.6

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 24
            context.translateBy(x: (size.width - 24 * scale) / 2, y: (size.height - 24 * scale) / 2)
            context.scaleBy(x: scale, y: scale)

            let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            let shading = GraphicsContext.Shading.color(color)

            // Center ring.
            context.stroke(
                Path(ellipseIn: CGRect(x: 9, y: 9, width: 6, height: 6)),
                with: shading,
                style: style
            )

            // Radiating ticks (axes + diagonals).
            let ticks: [(CGPoint, CGPoint)] = [
                (CGPoint(x: 12, y: 3), CGPoint(x: 12, y: 6)),
                (CGPoint(x: 12, y: 18), CGPoint(x: 12, y: 21)),
                (CGPoint(x: 3, y: 12), CGPoint(x: 6, y: 12)),
                (CGPoint(x: 18, y: 12), CGPoint(x: 21, y: 12)),
                (CGPoint(x: 5.5, y: 5.5), CGPoint(x: 7.5, y: 7.5)),
                (CGPoint(x: 16.5, y: 16.5), CGPoint(x: 18.5, y: 18.5)),
                (CGPoint(x: 18.5, y: 5.5), CGPoint(x: 16.5, y: 7.5)),
                (CGPoint(x: 7.5, y: 16.5), CGPoint(x: 5.5, y: 18.5))
            ]
            var path = Path()
            for tick in ticks {
                path.move(to: tick.0)
                path.addLine(to: tick.1)
            }
            context.stroke(path, with: shading, style: style)
        }
    }
}

#Preview {
    SpatialIcon()
        .frame(width: 40, height: 40)
        .padding()
        .background(DesignTokens.Palette.accent)
}
