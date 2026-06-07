import SwiftUI

/// Press-to-shrink button style used across SoundStage's tappable surfaces,
/// matching the design's `transform: scale(0.92–0.975)` press feedback.
struct ScaleButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
