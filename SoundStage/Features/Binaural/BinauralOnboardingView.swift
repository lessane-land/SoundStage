import SwiftUI

/// First-run introduction: what SoundStage is, the headphones requirement, and
/// how a sleep session works. Shown once, then dismissed via `onDone`.
struct BinauralOnboardingView: View {
    let onDone: () -> Void

    @State private var page = 0

    private struct Slide: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let body: String
    }

    private let slides: [Slide] = [
        Slide(icon: "waveform.path",
              title: "Welcome to SoundStage",
              body: "Binaural beats and real soundscapes, generated on your device for focus, calm, and sleep. Nothing streamed, nothing collected."),
        Slide(icon: "headphones",
              title: "Use headphones",
              body: "Binaural beats send a slightly different tone to each ear, so headphones are required for the effect — and for spatial audio with AirPods."),
        Slide(icon: "moon.stars.fill",
              title: "Drift off",
              body: "Pick a state, stack soundscapes like rain or ocean, then set a sleep timer that gently winds the beat down and fades out.")
    ]

    private let from = Color(hex: 0x6C5CE7)
    private let to = Color(hex: 0xC56BFF)
    private var gradient: LinearGradient {
        LinearGradient(colors: [from, to], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        ZStack {
            DesignTokens.Palette.backgroundPrimary.ignoresSafeArea()
            RadialGradient(colors: [to.opacity(0.18), .clear], center: .init(x: 0.5, y: 0.1), startRadius: 0, endRadius: 360)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                        slideView(slide).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: page)

                dots.padding(.bottom, 24)
                button.padding(.horizontal, 32).padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func slideView(_ slide: Slide) -> some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: slide.icon)
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 132, height: 132)
                .background(Circle().fill(gradient))
                .shadow(color: to.opacity(0.5), radius: 30, y: 10)
                .overlay(Circle().fill(LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .top, endPoint: .center)).clipShape(Circle()))
            VStack(spacing: 12) {
                Text(slide.title)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(slide.body)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 36)
            }
            Spacer()
        }
    }

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(slides.indices, id: \.self) { i in
                Capsule()
                    .fill(i == page ? AnyShapeStyle(gradient) : AnyShapeStyle(.white.opacity(0.18)))
                    .frame(width: i == page ? 22 : 8, height: 8)
                    .animation(.spring(response: 0.3), value: page)
            }
        }
    }

    private var button: some View {
        Button {
            if page < slides.count - 1 {
                withAnimation { page += 1 }
            } else {
                onDone()
            }
        } label: {
            Text(page < slides.count - 1 ? "Continue" : "Get Started")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Capsule().fill(gradient))
                .shadow(color: to.opacity(0.45), radius: 18, y: 6)
        }
        .buttonStyle(ScaleButtonStyle(pressedScale: 0.97))
    }
}
