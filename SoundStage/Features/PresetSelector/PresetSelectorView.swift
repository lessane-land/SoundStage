import SwiftUI

/// The "Choose your space" bottom sheet: a glassy panel with a 2-column grid of
/// preset cards. Tapping a card opens its detail editor; entering a space
/// commits it and dismisses.
struct PresetSelectorView: View {
    @State var viewModel: PresetSelectorViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var detailPreset: Preset?

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text("SOUNDSTAGE")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(.white.opacity(0.4))
                Text("Choose your space")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 6)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(viewModel.presets) { preset in
                        PresetCardView(preset: preset, isActive: viewModel.isSelected(preset)) {
                            detailPreset = preset
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 8)
        .presentationDetents([.fraction(0.74), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .presentationBackground(.ultraThinMaterial)
        .fullScreenCover(item: $detailPreset) { preset in
            PresetDetailView(
                preset: preset,
                isActive: viewModel.isSelected(preset),
                onActivate: { applied in
                    viewModel.activate(applied)
                    detailPreset = nil
                    dismiss()
                },
                onClose: { detailPreset = nil }
            )
        }
    }
}

#Preview {
    Color.black
        .sheet(isPresented: .constant(true)) {
            PresetSelectorView(viewModel: PresetSelectorViewModel(store: PresetStore()))
        }
}
