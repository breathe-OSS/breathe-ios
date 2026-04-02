//
//  BreatheWidgetLiveActivity.swift
//  BreatheWidget
//
//  Created by user948538 on 4/2/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct BreatheWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct BreatheWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BreatheWidgetAttributes.self) { context in
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

extension BreatheWidgetAttributes {
    fileprivate static var preview: BreatheWidgetAttributes {
        BreatheWidgetAttributes(name: "World")
    }
}

extension BreatheWidgetAttributes.ContentState {
    fileprivate static var smiley: BreatheWidgetAttributes.ContentState {
        BreatheWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: BreatheWidgetAttributes.ContentState {
         BreatheWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: BreatheWidgetAttributes.preview) {
   BreatheWidgetLiveActivity()
} contentStates: {
    BreatheWidgetAttributes.ContentState.smiley
    BreatheWidgetAttributes.ContentState.starEyes
}
