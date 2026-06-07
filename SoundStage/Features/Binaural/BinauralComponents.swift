import SwiftUI

/// Header for a bottom sheet: eyebrow + title with an optional trailing action.
struct BinauralSheetHeader<Action: View>: View {
    let state: BinauralState
    let eyebrow: String
    let title: String
    let action: () -> Action

    init(state: BinauralState, eyebrow: String, title: String, @ViewBuilder action: @escaping () -> Action) {
        self.state = state
        self.eyebrow = eyebrow
        self.title = title
        self.action = action
    }

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text(eyebrow)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(state.toColor)
                Text(title)
                    .font(.system(size: 25, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
            Spacer()
            action()
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 14)
    }
}

extension BinauralSheetHeader where Action == EmptyView {
    init(state: BinauralState, eyebrow: String, title: String) {
        self.init(state: state, eyebrow: eyebrow, title: title, action: { EmptyView() })
    }
}

/// The frosted dark background applied to every binaural sheet.
struct BinauralSheetBackground: View {
    var body: some View {
        Color(hex: 0x12121C)
            .overlay(Color.white.opacity(0.02))
            .ignoresSafeArea()
    }
}

/// Slim, label-less gradient slider (the design's `MiniSlider`).
struct BinauralMiniSlider: View {
    let state: BinauralState
    @Binding var value: Double

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let clamped = min(max(value, 0), 1)
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.1)).frame(height: 5)
                Capsule()
                    .fill(LinearGradient(colors: [state.fromColor, state.toColor], startPoint: .leading, endPoint: .trailing))
                    .frame(width: width * clamped, height: 5)
                    .shadow(color: state.toColor.opacity(0.4), radius: 5)
                Circle()
                    .fill(.white)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(state.toColor.opacity(0.19), lineWidth: 3))
                    .shadow(color: .black.opacity(0.5), radius: 3)
                    .offset(x: width * clamped - 8)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value = min(max(0, $0.location.x / width), 1) }
            )
        }
        .frame(height: 20)
    }
}

/// The gradient pill switch used across sheets.
struct BinauralSwitch: View {
    let state: BinauralState
    let on: Bool

    var body: some View {
        ZStack(alignment: on ? .trailing : .leading) {
            Capsule()
                .fill(on ? AnyShapeStyle(LinearGradient(colors: [state.fromColor, state.toColor], startPoint: .leading, endPoint: .trailing))
                         : AnyShapeStyle(.white.opacity(0.14)))
                .frame(width: 46, height: 28)
                .shadow(color: on ? state.toColor.opacity(0.4) : .clear, radius: 8)
            Circle()
                .fill(.white)
                .frame(width: 22, height: 22)
                .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                .padding(.horizontal, 3)
        }
        .animation(.easeInOut(duration: 0.2), value: on)
    }
}

/// A glassy row with an icon, label, optional subtitle and a trailing switch.
struct BinauralGlassToggle: View {
    let state: BinauralState
    let label: String
    var sub: String? = nil
    var icon: String? = nil
    let on: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        Button { onChange(!on) } label: {
            HStack(spacing: 12) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(on ? .white : .white.opacity(0.6))
                        .frame(width: 22)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    if let sub {
                        Text(sub)
                            .font(.system(size: 12.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 8)
                BinauralSwitch(state: state, on: on)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(on ? AnyShapeStyle(state.gradient.opacity(0.16)) : AnyShapeStyle(.white.opacity(0.04)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(on ? state.toColor.opacity(0.4) : .white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
