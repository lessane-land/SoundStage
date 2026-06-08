//
//  widget_extLiveActivity.swift
//  widget ext
//
//  Created by Morales, Vanesa on 08/06/2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct widget_extAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct widget_extLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: widget_extAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension widget_extAttributes {
    fileprivate static var preview: widget_extAttributes {
        widget_extAttributes(name: "World")
    }
}

extension widget_extAttributes.ContentState {
    fileprivate static var smiley: widget_extAttributes.ContentState {
        widget_extAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: widget_extAttributes.ContentState {
         widget_extAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: widget_extAttributes.preview) {
   widget_extLiveActivity()
} contentStates: {
    widget_extAttributes.ContentState.smiley
    widget_extAttributes.ContentState.starEyes
}
