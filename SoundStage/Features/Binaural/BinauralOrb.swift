import SwiftUI

/// The breathing gradient sphere with an orbit ring of luminous particles
/// (shown when spatial is on) — matching the design's hero orb.
struct BinauralOrb: View {
    let state: BinauralState
    let beatHz: Double
    let spatial: Double
    let isPlaying: Bool
    var size: CGFloat = 224

    private var ringSize: CGFloat { size * 1.46 }

    var body: some View {
        TimelineView(.animation(paused: !isPlaying && spatial < 0.01)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let period = max(1.6, min(4.6, 7 / sqrt(max(1, beatHz))))
            let breath = (isPlaying ? 0.045 : 0.012) * sin(t / period * 2 * .pi)
            let omega = (0.25 + spatial * 2.1) * (isPlaying ? 1 : 0.25)
            let angle = t * omega

            ZStack {
                // Deep glow.
                Circle()
                    .fill(RadialGradient(gradient: Gradient(stops: [
                        .init(color: state.toColor.opacity(0.33), location: 0),
                        .init(color: state.fromColor.opacity(0.13), location: 0.38),
                        .init(color: .clear, location: 0.66)
                    ]), center: .center, startRadius: 0, endRadius: size * 0.8))
                    .frame(width: size * 1.6, height: size * 1.6)
                    .blur(radius: 6)

                // Orbit ring + particles.
                orbitRing
                    .frame(width: ringSize, height: ringSize)
                    .rotationEffect(.radians(angle))
                    .opacity(0.15 + spatial * 0.85)

                // The sphere.
                orb
                    .frame(width: size, height: size)
                    .scaleEffect(1 + breath)
            }
            .frame(width: ringSize, height: ringSize)
        }
    }

    private var orbitRing: some View {
        ZStack {
            Circle().stroke(state.toColor.opacity(0.2), lineWidth: 1)
            ForEach(0..<4, id: \.self) { i in
                let lead = i == 0
                Circle()
                    .fill(.white)
                    .frame(width: lead ? 12 : 7, height: lead ? 12 : 7)
                    .shadow(color: state.toColor, radius: lead ? 10 : 6)
                    .shadow(color: state.toColor.opacity(0.8), radius: lead ? 6 : 3)
                    .shadow(color: .white.opacity(0.9), radius: 3)
                    .opacity(lead ? 1 : 0.7)
                    .offset(x: ringSize / 2)
                    .rotationEffect(.radians(Double(i) / 4 * 2 * .pi))
            }
        }
    }

    private var orb: some View {
        Circle()
            .fill(RadialGradient(colors: [state.fromColor, state.toColor],
                                 center: UnitPoint(x: 0.34, y: 0.28), startRadius: 0, endRadius: size * 0.62))
            .overlay(
                // glossy top sheen
                Ellipse()
                    .fill(RadialGradient(colors: [.white.opacity(0.6), .clear], center: .center, startRadius: 0, endRadius: size * 0.22))
                    .frame(width: size * 0.54, height: size * 0.34)
                    .offset(y: -size * 0.2)
                    .blur(radius: 2)
            )
            .overlay(
                // bottom inner shadow
                Circle()
                    .fill(LinearGradient(colors: [.clear, .black.opacity(0.35)], startPoint: .center, endPoint: .bottom))
            )
            .overlay(
                VStack(spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(beatText)
                            .font(.system(size: 56, weight: .heavy, design: .rounded))
                        Text("Hz")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    Text(state.band.uppercased())
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(.white.opacity(0.92))
                }
                .shadow(color: .black.opacity(0.3), radius: 12, y: 2)
            )
            .shadow(color: state.toColor.opacity(0.4), radius: 40, y: 20)
    }

    private var beatText: String {
        beatHz.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(beatHz))" : String(format: "%.1f", beatHz)
    }
}
