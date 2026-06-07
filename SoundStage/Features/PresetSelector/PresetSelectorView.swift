import SwiftUI

/// The preset picker, presented as a sheet from the player.
///
/// Lays out preset cards in an adaptive grid (one column on iPhone, more on
/// iPad). Selecting a card commits the choice and dismisses.
struct PresetSelectorView: View {
    @State var viewModel: PresetSelectorViewModel
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.adaptive(minimum: 260), spacing: DesignTokens.Spacing.m)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: DesignTokens.Spacing.m) {
                    ForEach(viewModel.presets) { preset in
                        PresetCardView(
                            preset: preset,
                            isActive: viewModel.isSelected(preset)
                        ) {
                            viewModel.select(preset)
                            dismiss()
                        }
                    }
                }
                .padding(DesignTokens.Spacing.m)
            }
            .background(DesignTokens.Palette.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Presets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(DesignTokens.Palette.accent)
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(DesignTokens.Palette.backgroundPrimary)
    }
}

#Preview {
    PresetSelectorView(viewModel: PresetSelectorViewModel(store: PresetStore()))
}
