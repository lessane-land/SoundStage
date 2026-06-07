import SwiftUI

/// A single glassmorphic preset card with an EQ-curve preview.
///
/// Shows the preset's name, description and tonal shape. When `isActive` the
/// card adopts the amber active-state treatment from the design tokens.
struct PresetCardView: View {
    let preset: Preset
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.s) {
                HStack {
                    Text(preset.label)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Palette.textPrimary)
                    Spacer()
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(DesignTokens.Palette.active)
                    }
                }

                EQCurveView(
                    bands: preset.eqBands,
                    lineColor: isActive ? DesignTokens.Palette.active : DesignTokens.Palette.accent
                )
                .frame(height: 56)

                Text(preset.description)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Palette.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DesignTokens.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
                    .fill(DesignTokens.Palette.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
                    .stroke(
                        isActive ? DesignTokens.Palette.active : DesignTokens.Palette.cardStroke,
                        lineWidth: isActive ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(preset.label)
        .accessibilityHint(preset.description)
        .accessibilityAddTraits(isActive ? [.isSelected, .isButton] : .isButton)
    }
}

#Preview {
    PresetCardView(
        preset: PresetStore().presets[0],
        isActive: true,
        onTap: {}
    )
    .padding()
    .background(DesignTokens.Palette.backgroundPrimary)
}
