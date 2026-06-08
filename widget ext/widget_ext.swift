//
//  widget_ext.swift
//  widget ext
//

import WidgetKit
import SwiftUI

struct SoundStageEntry: TimelineEntry {
    let date: Date
}

struct SoundStageProvider: TimelineProvider {
    func placeholder(in context: Context) -> SoundStageEntry { SoundStageEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (SoundStageEntry) -> Void) {
        completion(SoundStageEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SoundStageEntry>) -> Void) {
        completion(Timeline(entries: [SoundStageEntry(date: Date())], policy: .never))
    }
}

struct widget_extEntryView: View {
    @Environment(\.widgetFamily) private var family

    private let from = Color(.sRGB, red: 0x6C / 255, green: 0x5C / 255, blue: 0xE7 / 255)
    private let to = Color(.sRGB, red: 0xC5 / 255, green: 0x6B / 255, blue: 0xFF / 255)
    private var gradient: LinearGradient {
        LinearGradient(colors: [from, to], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    private var small: Bool { family == .systemSmall }

    var body: some View {
        VStack(alignment: .leading, spacing: small ? 8 : 10) {
            Circle().fill(gradient)
                .frame(width: small ? 40 : 48, height: small ? 40 : 48)
                .overlay(Image(systemName: "waveform.path").font(.system(size: small ? 19 : 23, weight: .bold)).foregroundStyle(.white))
                .shadow(color: to.opacity(0.5), radius: 8, y: 3)
            Spacer(minLength: 0)
            Text("SoundStage")
                .font(.system(size: small ? 17 : 20, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            HStack(spacing: 6) {
                Image(systemName: "play.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(to)
                Text("Tap to begin")
                    .font(.system(size: small ? 12 : 13.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(URL(string: "soundstage://play"))
    }
}

struct widget_ext: Widget {
    let kind: String = "widget_ext"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SoundStageProvider()) { _ in
            widget_extEntryView()
                .containerBackground(for: .widget) {
                    Color(.sRGB, red: 0x0A / 255, green: 0x0A / 255, blue: 0x12 / 255)
                }
        }
        .configurationDisplayName("SoundStage")
        .description("Open SoundStage and start a session.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
