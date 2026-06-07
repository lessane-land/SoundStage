import SwiftUI

/// A horizontal slider with a gradient-filled active side and a white thumb,
/// matching the design's `SSlider`. `value` is 0...1.
struct GradientSlider: View {
    let preset: Preset
    @Binding var value: Double

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let clamped = min(max(value, 0), 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 6)

                Capsule()
                    .fill(preset.gradient(angle: 0))
                    .frame(width: width * clamped, height: 6)
                    .shadow(color: preset.toColor.opacity(0.4), radius: 5)

                Circle()
                    .fill(.white)
                    .frame(width: 20, height: 20)
                    .overlay(Circle().stroke(preset.toColor.opacity(0.2), lineWidth: 4))
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                    .offset(x: width * clamped - 10)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        value = min(max(0, gesture.location.x / width), 1)
                    }
            )
        }
        .frame(height: 22)
    }
}
