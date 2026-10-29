import ActivityKit
import Foundation

/// The bedtime Live Activity: counts down to bedtime, then (once stale at bedtime) shows "resting".
struct BedtimeActivity: ActivityAttributes {
    struct ContentState: Codable, Hashable {}

    var bedtime: Date
    var bedLabel: String
    var wakeLabel: String
}
