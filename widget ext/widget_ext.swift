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

private struct QuickState: Identifiable {
    let id: String
    let name: String
    let from: UInt32
    let to: UInt32
    var gradient: LinearGradient {
        LinearGradient(colors: [col(from), col(to)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

private func col(_ hex: UInt32) -> Color {
    Color(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
}

private let quickStates: [QuickState] = [
    QuickState(id: "sleep", name: "Sleep", from: 0x3D8BFF, to: 0x7A8EFF),
    QuickState(id: "focus", name: "Focus", from: 0x6C5CE7, to: 0xC56BFF),
    QuickState(id: "relax", name: "Relax", from: 0x00D2FF, to: 0x0066FF)
]

struct widget_extEntryView: View {
    @Environment(\.widgetFamily) private var family

    private let accent = col(0xC56BFF)

    var body: some View {
        if family == .systemMedium {
            medium
        } else {
            small
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            Circle().fill(quickStates[1].gradient)
                .frame(width: 40, height: 40)
                .overlay(Image(systemName: "waveform.path").font(.system(size: 19, weight: .bold)).foregroundStyle(.white))
            Spacer(minLength: 0)
            Text("SoundStage").font(.system(size: 17, weight: .heavy, design: .rounded)).foregroundStyle(.white)
            HStack(spacing: 6) {
                Image(systemName: "play.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(accent)
                Text("Tap to begin").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(URL(string: "soundstage://play"))
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SoundStage").font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundStyle(.white)
            HStack(spacing: 10) {
                ForEach(quickStates) { s in
                    Link(destination: URL(string: "soundstage://state/\(s.id)")!) {
                        VStack(spacing: 8) {
                            Circle().fill(s.gradient).frame(width: 34, height: 34)
                                .overlay(Image(systemName: "play.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(.white.opacity(0.95)))
                            Text(s.name).font(.system(size: 12.5, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.06)))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.1), lineWidth: 1))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        .description("Start a session in one tap.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
