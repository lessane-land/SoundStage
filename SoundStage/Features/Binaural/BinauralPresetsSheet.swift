import SwiftUI

/// Favorites: a grid of saved presets plus a "Save current" card. Tap to load;
/// long-press for rename / delete (the design's `PresetsSheet`).
struct BinauralPresetsSheet: View {
    @Bindable var viewModel: BinauralViewModel
    let state: BinauralState

    @Environment(\.dismiss) private var dismiss

    @State private var dialog: Dialog?
    @State private var draftName = ""

    private enum Dialog: Identifiable {
        case new
        case rename(BinauralPreset)
        var id: String {
            switch self {
            case .new: return "new"
            case .rename(let p): return "rename-\(p.id)"
            }
        }
    }

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ZStack {
            BinauralSheetBackground()
            VStack(spacing: 0) {
                BinauralSheetHeader(state: state, eyebrow: "FAVORITES", title: "Presets")
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        saveCard
                        ForEach(viewModel.presets) { preset in
                            card(for: preset)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert(dialogTitle, isPresented: dialogPresented) {
            TextField("Preset name", text: $draftName)
            Button("Cancel", role: .cancel) { dialog = nil }
            Button("Save") { confirmDialog() }
        }
    }

    private var saveCard: some View {
        Button {
            draftName = state.name
            dialog = .new
        } label: {
            VStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(state.gradient))
                    .shadow(color: state.toColor.opacity(0.5), radius: 10, y: 3)
                Text("Save current")
                    .font(.system(size: 14.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, minHeight: 150)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(state.gradient.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(state.toColor.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            )
        }
        .buttonStyle(.plain)
    }

    private func card(for preset: BinauralPreset) -> some View {
        let st = BinauralCatalog.all.first { $0.id == preset.stateId } ?? BinauralCatalog.default
        return Button {
            viewModel.loadPreset(preset)
            Task { try? await Task.sleep(for: .milliseconds(160)); dismiss() }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottomTrailing) {
                    st.gradient.frame(height: 64)
                        .overlay(
                            RadialGradient(colors: [.white.opacity(0.3), .clear],
                                           center: .init(x: 0.2, y: 0.1), startRadius: 0, endRadius: 70)
                        )
                    Text(st.band.uppercased())
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.trailing, 12)
                        .padding(.bottom, 10)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(preset.name)
                        .font(.system(size: 15.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(preset.summary)
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.42))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 13)
                .padding(.top, 11)
                .padding(.bottom, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(hex: 0x141420))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(st.toColor.opacity(0.27), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                draftName = preset.name
                dialog = .rename(preset)
            } label: { Label("Rename", systemImage: "pencil") }
            Button(role: .destructive) {
                viewModel.deletePreset(preset)
            } label: { Label("Delete", systemImage: "trash") }
        }
    }

    // MARK: - Dialog

    private var dialogTitle: String {
        if case .rename = dialog { return "Rename preset" }
        return "Save preset"
    }

    private var dialogPresented: Binding<Bool> {
        Binding(get: { dialog != nil }, set: { if !$0 { dialog = nil } })
    }

    private func confirmDialog() {
        let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { dialog = nil; return }
        switch dialog {
        case .new: viewModel.saveCurrentPreset(named: name)
        case .rename(let preset): viewModel.renamePreset(preset, to: name)
        case .none: break
        }
        dialog = nil
    }
}
