import ActivityKit
import Foundation

/// Starts the bedtime Live Activity when the app is open in the 4 hours before bedtime,
/// and replaces it if bedtime changes. iOS keeps it at most 8 hours, so it doesn't span the night.
enum LiveBedtime {
    static func refresh() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let bed = Lock.night().bed
        let untilBed = bed.timeIntervalSinceNow
        let wanted = untilBed > 60 && untilBed < 4 * 3600 && Lock.hasApps
        let running = Activity<BedtimeActivity>.activities
        for a in running where !wanted || a.attributes.bedtime != bed {
            Task { await a.end(nil, dismissalPolicy: .immediate) }
        }
        guard wanted, !running.contains(where: { $0.attributes.bedtime == bed }) else { return }
        let attributes = BedtimeActivity(bedtime: bed, bedLabel: Lock.clock(Lock.bedMinutes), wakeLabel: Lock.clock(Lock.wakeMinutes))
        _ = try? Activity.request(attributes: attributes, content: .init(state: .init(), staleDate: bed))
    }
}
