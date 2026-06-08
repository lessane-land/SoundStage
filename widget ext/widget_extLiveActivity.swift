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

struct widget_extLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SoundStageSessionAttributes.self) { context in
            lockScreen(context.state)
                .activityBackgroundTint(Color.black.opacity(0.5))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Circle().fill(gradient(s)).frame(width: 30, height: 30)
                        .overlay(Image(systemName: "moon.stars.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(.white))
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
                Image(systemName: "moon.stars.fill").foregroundStyle(color(s.toHex))
            } compactTrailing: {
                countdown(s).font(.system(.caption2, design: .rounded).weight(.bold))
                    .monospacedDigit().foregroundStyle(.white)
            } minimal: {
                Image(systemName: "moon.stars.fill").foregroundStyle(color(s.toHex))
            }
            .keylineTint(color(s.toHex))
        }
    }

    private func lockScreen(_ s: SoundStageSessionAttributes.ContentState) -> some View {
        HStack(spacing: 14) {
            Circle().fill(gradient(s)).frame(width: 44, height: 44)
                .overlay(Image(systemName: "moon.stars.fill").font(.system(size: 18, weight: .bold)).foregroundStyle(.white))
                .shadow(color: color(s.toHex).opacity(0.6), radius: 8)
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
            Image(systemName: "infinity")
        }
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
