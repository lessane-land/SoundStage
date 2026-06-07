import SwiftUI

/// A preset card with its geometric glyph, name and description. Active cards
/// glow in the preset's accent; inactive cards carry a gradient hairline.
struct PresetCardView: View {
    let preset: Preset
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                PresetGlyph(preset: preset)
                    .frame(height: 64)

                Spacer(minLength: 8)

                HStack(spacing: 6) {
                    Text(preset.label)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if isActive {
                        Circle()
                            .fill(preset.toColor)
                            .frame(width: 7, height: 7)
                            .shadow(color: preset.toColor, radius: 4)
                    }
                }

                Text(preset.description)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(DesignTokens.Palette.cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(preset.gradient(opacity: isActive ? 0.10 : 0))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        isActive ? AnyShapeStyle(preset.toColor) : AnyShapeStyle(preset.gradient(opacity: 0.3)),
                        lineWidth: isActive ? 1.5 : 1
                    )
            )
            .shadow(color: isActive ? preset.toColor.opacity(0.45) : .clear, radius: 16)
        }
        .buttonStyle(ScaleButtonStyle(pressedScale: 0.975))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(preset.label)
        .accessibilityHint(preset.description)
        .accessibilityAddTraits(isActive ? [.isSelected, .isButton] : .isButton)
    }
}

#Preview {
    ZStack {
        DesignTokens.Palette.backgroundPrimary.ignoresSafeArea()
        HStack(spacing: 14) {
            PresetCardView(preset: PresetStore().presets[1], isActive: true, onTap: {})
            PresetCardView(preset: PresetStore().presets[2], isActive: false, onTap: {})
        }
        .padding()
    }
}
