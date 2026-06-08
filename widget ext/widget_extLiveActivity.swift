//
//  widget_extLiveActivity.swift
//  widget ext
//

import ActivityKit
import WidgetKit
import SwiftUI

private func color(_ hex: UInt32) -> Color {
    Color(.sRGB,
          red: Double((hex >> 16) & 0xFF) / 255,
          green: Double((hex >> 8) & 0xFF) / 255,
          blue: Double(hex & 0xFF) / 255)
}

private func gradient(_ s: SoundStageSessionAttributes.ContentState) -> LinearGradient {
    LinearGradient(colors: [color(s.fromHex), color(s.toHex)], startPoint: .topLeading, endPoint: .bottomTrailing)
}

/// The stage-colored gradient ball, with a soft top highlight like the in-app orb.
private struct Orb: View {
    let state: SoundStageSessionAttributes.ContentState
    var size: CGFloat
    var body: some View {
        Circle()
            .fill(gradient(state))
            .overlay(
                Circle().fill(
                    RadialGradient(colors: [.white.opacity(0.55), .clear],
                                   center: .init(x: 0.35, y: 0.3),
                                   startRadius: 0, endRadius: size * 0.6)
                )
            )
            .frame(width: size, height: size)
            .shadow(color: color(state.toHex).opacity(0.6), radius: size * 0.18)
    }
}

struct widget_extLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SoundStageSessionAttributes.self) { context in
            lockScreen(context.state)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Orb(state: s, size: 34)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(s).font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white).monospacedDigit()
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 1) {
                        Text(s.stateName).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        Text(s.bandHz).font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.6))
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    progressBar(s)
                }
            } compactLeading: {
                Orb(state: s, size: 22)
            } compactTrailing: {
                compactValue(s)
            } minimal: {
                Orb(state: s, size: 22)
            }
            .keylineTint(color(s.toHex))
        }
    }

    private func lockScreen(_ s: SoundStageSessionAttributes.ContentState) -> some View {
        HStack(spacing: 14) {
            Orb(state: s, size: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(s.stateName).font(.system(size: 17, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                Text(s.bandHz).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.55))
                progressBar(s).padding(.top, 2)
            }
            Spacer()
            countdown(s).font(.system(size: 26, weight: .heavy, design: .rounded))
                .monospacedDigit().foregroundStyle(.white)
        }
        .padding(16)
    }

    @ViewBuilder
    private func countdown(_ s: SoundStageSessionAttributes.ContentState) -> some View {
        if let end = s.endDate {
            Text(timerInterval: Date()...end, countsDown: true)
        } else {
            Image(systemName: "waveform").foregroundStyle(color(s.toHex))
        }
    }

    /// Compact-island trailing: the live countdown during a session, else the
    /// beat frequency so the island always says something useful.
    @ViewBuilder
    private func compactValue(_ s: SoundStageSessionAttributes.ContentState) -> some View {
        if let end = s.endDate {
            Text(timerInterval: Date()...end, countsDown: true)
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .frame(maxWidth: 52)
        } else {
            HStack(spacing: 2) {
                Text(hzText(s.beatHz))
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                Text("Hz")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .opacity(0.7)
            }
            .foregroundStyle(color(s.toHex))
        }
    }

    private func hzText(_ hz: Double) -> String {
        hz.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(hz))" : String(format: "%.1f", hz)
    }

    @ViewBuilder
    private func progressBar(_ s: SoundStageSessionAttributes.ContentState) -> some View {
        if let end = s.endDate {
            ProgressView(timerInterval: s.startDate...end, countsDown: false)
                .progressViewStyle(.linear)
                .tint(color(s.toHex))
                .labelsHidden()
        } else {
            Capsule().fill(gradient(s)).frame(height: 4).opacity(0.7)
        }
    }
}
