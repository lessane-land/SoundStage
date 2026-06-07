import SwiftUI

/// Abstract geometric art that *is* the preset's icon, stroked in the preset's
/// gradient (or a solid `tint`, e.g. white over the detail header). Drawn in a
/// normalized 100x100 space and scaled to fit.
struct PresetGlyph: View {
    let preset: Preset
    var lineWidth: CGFloat = 2.4
    /// When set, strokes solid in this color instead of the gradient.
    var tint: Color?

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 100
            context.translateBy(
                x: (size.width - 100 * scale) / 2,
                y: (size.height - 100 * scale) / 2
            )
            context.scaleBy(x: scale, y: scale)

            let shading: GraphicsContext.Shading = tint.map { .color($0) }
                ?? .linearGradient(
                    Gradient(colors: [preset.fromColor, preset.toColor]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 100, y: 100)
                )

            func stroke(_ path: Path, opacity: Double = 1, width: CGFloat? = nil) {
                var ctx = context
                ctx.opacity = opacity
                ctx.stroke(
                    path,
                    with: shading,
                    style: StrokeStyle(lineWidth: width ?? lineWidth, lineCap: .round, lineJoin: .round)
                )
            }
            func fill(_ path: Path, opacity: Double = 1) {
                var ctx = context
                ctx.opacity = opacity
                ctx.fill(path, with: shading)
            }

            switch preset.shape {
            case .arcs:
                stroke(arc(center: CGPoint(x: 50, y: 86), radius: 32), opacity: 0.95)
                stroke(arc(center: CGPoint(x: 50, y: 86), radius: 48), opacity: 0.60)
                stroke(arc(center: CGPoint(x: 50, y: 86), radius: 64), opacity: 0.32)
                fill(Path(ellipseIn: CGRect(x: 46, y: 82, width: 8, height: 8)))

            case .angular:
                stroke(poly([(16, 78), (40, 30), (52, 54), (70, 18), (84, 46)]), opacity: 0.95)
                stroke(poly([(16, 90), (84, 90)]), opacity: 0.40)
                stroke(poly([(28, 90), (40, 66), (56, 90)]), opacity: 0.55)

            case .layers:
                stroke(poly([(14, 30), (86, 30)]), opacity: 0.30)
                stroke(poly([(20, 46), (80, 46)]), opacity: 0.50)
                stroke(poly([(14, 62), (86, 62)]), opacity: 0.75)
                stroke(poly([(10, 78), (90, 78)]), opacity: 1.0, width: lineWidth * 1.4)

            case .curves:
                stroke(cubic(from: CGPoint(x: 12, y: 64), c1: CGPoint(x: 32, y: 24),
                             c2: CGPoint(x: 52, y: 88), to: CGPoint(x: 88, y: 38)), opacity: 0.95)
                stroke(cubic(from: CGPoint(x: 12, y: 78), c1: CGPoint(x: 36, y: 44),
                             c2: CGPoint(x: 56, y: 96), to: CGPoint(x: 90, y: 56)), opacity: 0.45)

            case .grid:
                let w = lineWidth * 0.85
                stroke(poly([(30, 22), (30, 82)]), opacity: 0.45, width: w)
                stroke(poly([(50, 22), (50, 82)]), opacity: 0.45, width: w)
                stroke(poly([(70, 22), (70, 82)]), opacity: 0.45, width: w)
                stroke(poly([(22, 38), (82, 38)]), opacity: 0.45, width: w)
                stroke(poly([(22, 58), (82, 58)]), opacity: 0.45, width: w)
                stroke(Path(roundedRect: CGRect(x: 42, y: 42, width: 16, height: 16), cornerRadius: 2),
                       opacity: 0.9, width: w)

            case .pulse:
                stroke(poly([(16, 36), (34, 64), (50, 28), (62, 72), (72, 50)]), width: lineWidth * 1.3)
                stroke(poly([(30, 84), (46, 84)]), opacity: 0.40)
                stroke(poly([(54, 84), (84, 84)]), opacity: 0.40)
            }
        }
    }

    // MARK: - Path builders (100x100 space)

    private func poly(_ points: [(CGFloat, CGFloat)]) -> Path {
        var path = Path()
        for (index, point) in points.enumerated() {
            let cgPoint = CGPoint(x: point.0, y: point.1)
            if index == 0 { path.move(to: cgPoint) } else { path.addLine(to: cgPoint) }
        }
        return path
    }

    private func cubic(from: CGPoint, c1: CGPoint, c2: CGPoint, to: CGPoint) -> Path {
        var path = Path()
        path.move(to: from)
        path.addCurve(to: to, control1: c1, control2: c2)
        return path
    }

    /// Quarter arc sweeping the upper-right quadrant from a bottom pivot.
    private func arc(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        let steps = 24
        for step in 0...steps {
            let degrees = Double(step) / Double(steps) * 90
            let radians = degrees * .pi / 180
            let x = center.x + radius * CGFloat(cos(radians))
            let y = center.y - radius * CGFloat(sin(radians))
            let point = CGPoint(x: x, y: y)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}

#Preview {
    ZStack {
        DesignTokens.Palette.backgroundPrimary.ignoresSafeArea()
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 16) {
            ForEach(PresetStore().presets) { preset in
                PresetGlyph(preset: preset)
                    .frame(width: 80, height: 80)
            }
        }
        .padding()
    }
}
