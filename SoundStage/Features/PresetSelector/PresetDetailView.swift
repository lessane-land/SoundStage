import SwiftUI

/// Full-screen preset editor with a gradient geometric header, the three
/// spatial sliders, a Frequency Shape preview and the enter/save actions.
struct PresetDetailView: View {
    let preset: Preset
    let isActive: Bool
    /// Called with the (possibly tweaked) preset when the user enters the space.
    let onActivate: (Preset) -> Void
    let onClose: () -> Void
    /// Live preview of the current slider values (reverb/EQ apply immediately).
    var onPreview: (Preset) -> Void = { _ in }

    @State private var room: Double
    @State private var reverb: Double
    @State private var width: Double
    @State private var saved = false

    init(
        preset: Preset,
        isActive: Bool,
        onActivate: @escaping (Preset) -> Void,
        onClose: @escaping () -> Void,
        onPreview: @escaping (Preset) -> Void = { _ in }
    ) {
        self.preset = preset
        self.isActive = isActive
        self.onActivate = onActivate
        self.onClose = onClose
        self.onPreview = onPreview
        _room = State(initialValue: Double(preset.roomSize))
        _reverb = State(initialValue: Double(preset.reverbBlend))
        _width = State(initialValue: Double(preset.stereoWidth))
    }

    var body: some View {
        ZStack(alignment: .top) {
            DesignTokens.Palette.backgroundElevated.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 22) {
                        slider(label: "Room Size", value: $room)
                        slider(label: "Reverb Depth", value: $reverb)
                        slider(label: "Stereo Width", value: $width)
                    }
                    .padding(.top, 14)
                    frequencyCard
                        .padding(.top, 26)
                }
                .padding(.horizontal, 24)
                footer
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { onPreview(tweakedPreset) }
        .onChange(of: room) { _, _ in onPreview(tweakedPreset) }
        .onChange(of: reverb) { _, _ in onPreview(tweakedPreset) }
        .onChange(of: width) { _, _ in onPreview(tweakedPreset) }
    }

    // MARK: - Header

    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            preset.gradient()
                .opacity(0.9)

            // top highlight
            RadialGradient(
                colors: [.white.opacity(0.18), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 240
            )

            // inverted glyph wash
            PresetGlyph(preset: preset, lineWidth: 3.2, tint: .white)
                .padding(-20)
                .opacity(0.32)
                .blendMode(.softLight)

            // fade into the body
            LinearGradient(
                colors: [DesignTokens.Palette.backgroundElevated, .clear],
                startPoint: .bottom,
                endPoint: .center
            )

            VStack(alignment: .leading, spacing: 3) {
                Text("SPATIAL PRESET")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.85))
                Text(preset.label)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 12, y: 2)
                Text(preset.description)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)

            closeButton
        }
        .frame(height: 264)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "chevron.down")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: Circle())
        }
        .padding(.top, 12)
        .padding(.leading, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityLabel("Close")
    }

    // MARK: - Sliders

    private func slider(label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(label)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                Spacer()
                Text("\(Int((value.wrappedValue * 100).rounded()))%")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .monospacedDigit()
            }
            GradientSlider(preset: preset, value: value)
        }
    }

    private var frequencyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Frequency Shape")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                Spacer()
                Text("20Hz — 20kHz")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(0.4)
                    .foregroundStyle(.white.opacity(0.35))
            }
            MiniEQView(preset: preset, room: room, reverb: reverb, width: width)
                .frame(height: 72)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DesignTokens.Palette.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                saved = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: saved ? "checkmark" : "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(preset.toColor)
                    Text(saved ? "Saved" : "Save Custom")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 20)
                .frame(height: 52)
                .background(
                    Capsule().strokeBorder(preset.toColor.opacity(0.4), lineWidth: 1.5)
                )
            }
            .buttonStyle(ScaleButtonStyle())

            Button {
                onActivate(tweakedPreset)
            } label: {
                Text(isActive ? "Active Space" : "Enter This Space")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Capsule().fill(preset.gradient()))
                    .shadow(color: preset.toColor.opacity(0.45), radius: 14, y: 6)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 30)
    }

    private var tweakedPreset: Preset {
        var preset = preset
        preset.roomSize = Float(room)
        preset.reverbBlend = Float(reverb)
        preset.stereoWidth = Float(width)
        return preset
    }
}

#Preview {
    PresetDetailView(preset: PresetStore().presets[2], isActive: false, onActivate: { _ in }, onClose: {})
}
