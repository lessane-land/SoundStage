import SwiftUI

/// The waveform scrubber: vertical bars where the played region is washed in
/// the preset gradient and the unplayed region is white @ 15%. A live ripple
/// breathes near the playhead while playing. Dragging scrubs.
struct WaveformView: View {
    let preset: Preset
    var progress: Double
    var isPlaying: Bool
    var onScrub: ((Double) -> Void)?
    var onScrubEnded: (() -> Void)?

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(paused: !isPlaying)) { timeline in
                Canvas { context, size in
                    draw(context: context, size: size,
                         time: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let fraction = min(max(0, value.location.x / proxy.size.width), 1)
                        onScrub?(fraction)
                    }
                    .onEnded { _ in onScrubEnded?() }
            )
        }
        .accessibilityElement()
        .accessibilityLabel("Playback position")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }

    private func draw(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        let count = Self.bars.count
        let slot = size.width / CGFloat(count)
        let barWidth = min(3.5, slot - 2)
        let playIndex = progress * Double(count)

        for (index, base) in Self.bars.enumerated() {
            let distance = abs(Double(index) - playIndex)
            let ripple = isPlaying ? max(0, 1 - distance / 5) * 0.22 * (0.5 + 0.5 * sin(time * 6 - Double(index) * 0.5)) : 0
            let breathe = isPlaying ? 0.04 * sin(time * 2.2 + Double(index) * 0.4) : 0
            let height = CGFloat(min(1, max(0.1, base + ripple + breathe))) * size.height

            let x = slot * CGFloat(index) + slot / 2
            let rect = CGRect(x: x - barWidth / 2, y: (size.height - height) / 2, width: barWidth, height: height)
            let bar = Path(roundedRect: rect, cornerRadius: 3)

            let played = Double(index) <= playIndex
            let color = played
                ? preset.color(atFraction: Double(index) / Double(count - 1))
                : Color.white.opacity(0.15)
            context.fill(bar, with: .color(color))
        }

        // Playhead.
        let headX = CGFloat(progress) * size.width
        let head = Path(roundedRect: CGRect(x: headX - 1, y: -3, width: 2, height: size.height + 6), cornerRadius: 1)
        context.fill(head, with: .color(.white))
    }

    /// Stable seeded bar profile (matches the design's `makeBars(58, 4821)`).
    static let bars: [Double] = {
        var state = 4821
        func rnd() -> Double {
            state = (state * 9301 + 49297) % 233280
            return Double(state) / 233280
        }
        var out: [Double] = []
        for i in 0..<58 {
            let env = 0.42 + 0.34 * sin(Double(i) * 0.22) + 0.20 * sin(Double(i) * 0.07 + 1.7)
            out.append(max(0.12, min(1, env * (0.7 + rnd() * 0.6))))
        }
        return out
    }()
}

#Preview {
    WaveformView(preset: PresetStore().presets[2], progress: 0.34, isPlaying: true, onScrub: { _ in })
        .frame(height: 56)
        .padding()
        .background(DesignTokens.Palette.backgroundPrimary)
}
