//
//  MemoryAisleWidgetsLiveActivity.swift
//  MemoryAisleWidgets
//
//  Created by Kevin Minn on 4/6/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct MemoryAisleWidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct MemoryAisleWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MemoryAisleWidgetsAttributes.self) { context in
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

extension MemoryAisleWidgetsAttributes {
    fileprivate static var preview: MemoryAisleWidgetsAttributes {
        MemoryAisleWidgetsAttributes(name: "World")
    }
}

extension MemoryAisleWidgetsAttributes.ContentState {
    fileprivate static var smiley: MemoryAisleWidgetsAttributes.ContentState {
        MemoryAisleWidgetsAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: MemoryAisleWidgetsAttributes.ContentState {
         MemoryAisleWidgetsAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: MemoryAisleWidgetsAttributes.preview) {
   MemoryAisleWidgetsLiveActivity()
} contentStates: {
    MemoryAisleWidgetsAttributes.ContentState.smiley
    MemoryAisleWidgetsAttributes.ContentState.starEyes
}
