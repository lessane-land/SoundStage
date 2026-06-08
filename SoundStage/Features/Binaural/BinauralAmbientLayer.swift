import SwiftUI

/// Full-bleed animated texture behind the orb, drawn per soundscape and tinted
/// in the state color — matching the design's AmbientLayer (rain falling, ocean
/// waves, forest motes, wind streaks, noise).
struct BinauralAmbientLayer: View {
    let soundscapes: Set<Ambience>
    let color: Color
    let intensity: Double
    let isPlaying: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Particle {
        let x: Double, y: Double, v: Double, len: Double, ph: Double, r: Double
    }

    private static let particles: [Particle] = {
        var rng = SystemRandomNumberGenerator()
        return (0..<90).map { _ in
            Particle(x: .random(in: 0...1, using: &rng), y: .random(in: 0...1, using: &rng),
                     v: .random(in: 0.4...1, using: &rng), len: .random(in: 0.04...0.13, using: &rng),
                     ph: .random(in: 0...(2 * .pi), using: &rng), r: .random(in: 0.6...2.2, using: &rng))
        }
    }()

    var body: some View {
        TimelineView(.animation(paused: reduceMotion || (!isPlaying && intensity < 0.05))) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for kind in soundscapes.sorted(by: { $0.code < $1.code }) {
                    draw(visual(for: kind), context: context, size: size, t: t)
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// Maps each soundscape to a drawable texture style (new soundscapes reuse
    /// the closest existing visual until the redesign ships dedicated art).
    private enum Visual { case rain, ocean, forest, wind, noise }

    private func visual(for kind: Ambience) -> Visual {
        switch kind {
        case .rain, .stream: return .rain
        case .ocean: return .ocean
        case .forest, .fire: return .forest
        case .wind: return .wind
        case .noise, .thunder, .cafe: return .noise
        }
    }

    private func draw(_ kind: Visual, context: GraphicsContext, size: CGSize, t: TimeInterval) {
        let w = size.width, h = size.height
        let speed = isPlaying ? 1.0 : 0.18
        let level = max(0.05, intensity)
        func tint(_ a: Double) -> GraphicsContext.Shading { .color(color.opacity(a)) }

        switch kind {
        case .rain:
            for p in Self.particles.prefix(60) {
                let y = ((p.y + t * 0.55 * p.v * speed).truncatingRemainder(dividingBy: 1.15)) - 0.1
                let x = p.x * w
                var path = Path()
                path.move(to: CGPoint(x: x, y: y * h))
                path.addLine(to: CGPoint(x: x + 1.5, y: (y + p.len) * h))
                context.stroke(path, with: tint(0.1 + 0.22 * level * p.v),
                               style: StrokeStyle(lineWidth: 1.1 + p.r * 0.4, lineCap: .round))
            }
        case .ocean:
            for i in 0..<6 {
                let p = Self.particles[i]
                let baseY = (0.16 + Double(i) * 0.13) * h
                var path = Path()
                var x = 0.0
                while x <= w {
                    let yy = baseY + sin(x * 0.012 + t * (0.5 + Double(i) * 0.12) * speed + p.ph) * (10 + 10 * level)
                    if x == 0 { path.move(to: CGPoint(x: x, y: yy)) } else { path.addLine(to: CGPoint(x: x, y: yy)) }
                    x += 14
                }
                context.stroke(path, with: tint(0.06 + 0.16 * level), lineWidth: 1.6)
            }
        case .forest:
            for p in Self.particles.prefix(34) {
                let y = ((p.y - t * 0.06 * p.v * speed).truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1)
                let x = (p.x + sin(t * 0.4 * speed + p.ph) * 0.02) * w
                let radius = p.r * (0.8 + level)
                let rect = CGRect(x: x - radius, y: y * h - radius, width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: rect), with: tint(0.12 + 0.3 * level * (0.5 + 0.5 * sin(t * 1.5 + p.ph))))
            }
        case .wind:
            for p in Self.particles.prefix(26) {
                let x = ((p.x + t * 0.28 * p.v * speed).truncatingRemainder(dividingBy: 1.2)) - 0.1
                let y = p.y + sin(t * 0.6 * speed + p.ph) * 0.03
                let len = (p.len + 0.12) * w
                var path = Path()
                path.move(to: CGPoint(x: x * w, y: y * h))
                path.addLine(to: CGPoint(x: x * w + len, y: y * h + 6))
                context.stroke(path, with: tint(0.1 + 0.18 * level * p.v),
                               style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
            }
        case .noise:
            var rng = SystemRandomNumberGenerator()
            for _ in 0..<90 {
                let x = Double.random(in: 0...1, using: &rng) * w
                let y = Double.random(in: 0...1, using: &rng) * h
                context.fill(Path(CGRect(x: x, y: y, width: 2, height: 2)),
                             with: tint(0.05 + 0.25 * level * Double.random(in: 0...1, using: &rng)))
            }
        }
    }
}
