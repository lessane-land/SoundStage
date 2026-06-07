import SwiftUI

/// A labelled gradient slider (0...1) matching the design's `FSlider`.
struct BinauralSlider: View {
    let state: BinauralState
    let label: String
    let valueText: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(label)
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text(valueText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            GeometryReader { proxy in
                let width = proxy.size.width
                let clamped = min(max(value, 0), 1)
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.1)).frame(height: 6)
                    Capsule()
                        .fill(LinearGradient(colors: [state.fromColor, state.toColor], startPoint: .leading, endPoint: .trailing))
                        .frame(width: width * clamped, height: 6)
                        .shadow(color: state.toColor.opacity(0.47), radius: 6)
                    Circle()
                        .fill(.white)
                        .frame(width: 19, height: 19)
                        .overlay(Circle().stroke(state.toColor.opacity(0.2), lineWidth: 4))
                        .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                        .offset(x: width * clamped - 9.5)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value = min(max(0, $0.location.x / width), 1) }
                )
            }
            .frame(height: 22)
        }
    }
}
