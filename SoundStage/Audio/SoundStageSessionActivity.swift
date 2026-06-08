import Foundation
import ActivityKit

/// Shared between the app (which starts/updates the Live Activity) and the
/// widget extension (which renders it). This one file must belong to BOTH
/// targets — tick "widget ext" in its Target Membership in Xcode.
struct SoundStageSessionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var stateName: String        // e.g. "Deep Sleep"
        var bandHz: String           // e.g. "DELTA · 2.5 Hz"
        var fromHex: UInt32          // gradient start
        var toHex: UInt32            // gradient end
        var startDate: Date          // for the progress ring
        var endDate: Date?           // nil = open-ended (∞)
        var isPlaying: Bool
    }

    var title: String                // "Sleep session"
}
