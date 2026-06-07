import SwiftUI

/// The Soundscape Mixer: stack any number of soundscapes and set each one's
/// level independently (the design's `MixerSheet`).
struct BinauralMixerSheet: View {
    @Bindable var viewModel: BinauralViewModel
    let state: BinauralState

    var body: some View {
        ZStack {
            BinauralSheetBackground()
            VStack(spacing: 0) {
                BinauralSheetHeader(state: state, eyebrow: "LAYER & STACK", title: "Soundscape Mixer") {
                    if viewModel.activeCount > 0 {
                        Button { viewModel.clearMix() } label: {
                            Text("Clear all")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(.white.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(Ambience.allCases) { item in
                            row(for: item)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func row(for item: Ambience) -> some View {
        let on = viewModel.isActive(item)
        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(on ? .white : .white.opacity(0.55))
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(on ? AnyShapeStyle(state.gradient) : AnyShapeStyle(.white.opacity(0.06)))
                    )
                    .shadow(color: on ? state.toColor.opacity(0.4) : .clear, radius: 8, y: 2)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.label)
                        .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(on ? "\(Int(viewModel.layerVolume(item) * 100))%" : "Off")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(on ? state.toColor : .white.opacity(0.35))
                }
                Spacer(minLength: 8)
                Button { viewModel.toggleAmbience(item) } label: {
                    BinauralSwitch(state: state, on: on)
                }
                .buttonStyle(.plain)
            }
            if on {
                BinauralMiniSlider(
                    state: state,
                    value: Binding(
                        get: { viewModel.layerVolume(item) },
                        set: { viewModel.setLayerVolume(item, $0) }
                    )
                )
                .padding(.leading, 52)
                .padding(.top, 12)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(on ? AnyShapeStyle(state.gradient.opacity(0.14)) : AnyShapeStyle(.white.opacity(0.035)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(on ? state.toColor.opacity(0.4) : .white.opacity(0.08), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: on)
    }
}
