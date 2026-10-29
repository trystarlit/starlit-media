import ActivityKit
import SwiftUI
import WidgetKit

@main
struct StarlitWidgets: WidgetBundle {
    var body: some Widget {
        TonightWidget()
        BedtimeLiveActivity()
    }
}

// MARK: - look

enum W {
    static let night = Color(red: 15/255, green: 13/255, blue: 11/255)
    static let ivory = Color(red: 240/255, green: 233/255, blue: 223/255)
    static let muted = Color(red: 155/255, green: 144/255, blue: 131/255)
    static let amber = Color(red: 244/255, green: 212/255, blue: 160/255)
    static let glow = Color(red: 222/255, green: 180/255, blue: 118/255)

    static func font(_ size: CGFloat, _ weight: String = "Regular") -> Font { .custom("Geist-\(weight)", size: size) }

    static func hm(_ seconds: TimeInterval) -> String {
        let m = max(0, Int(seconds / 60))
        return "\(m / 60)h \(String(format: "%02d", m % 60))m"
    }
}

/// The starlit orbit: a ring with a gap at -45°, the amber star sitting in it.
struct MiniLogo: View {
    var size: CGFloat
    var body: some View {
        ZStack {
            Ring().stroke(W.ivory, style: StrokeStyle(lineWidth: size * 0.085, lineCap: .butt))
            Circle().fill(W.amber).frame(width: size * 0.26, height: size * 0.26)
                .offset(x: size * 0.42 * cos(-.pi / 4), y: size * 0.42 * sin(-.pi / 4))
        }
        .frame(width: size, height: size)
    }

    private struct Ring: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: min(rect.width, rect.height) * 0.42,
                     startAngle: .degrees(-45 + 22), endAngle: .degrees(-45 - 22 + 360), clockwise: false)
            return p
        }
    }
}

// MARK: - home + lock screen widget

struct TonightEntry: TimelineEntry {
    let date: Date
    let bed: Date
    let wake: Date
    let resting: Bool
    let streak: Int
    let night: Int
    let wakeLabel: String
}

struct TonightProvider: TimelineProvider {
    func placeholder(in context: Context) -> TonightEntry { entry(at: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (TonightEntry) -> Void) { completion(entry(at: Date())) }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TonightEntry>) -> Void) {
        let now = Date()
        // a fresh countdown every 5 minutes for the next 12 hours
        let entries = (0..<144).map { entry(at: now.addingTimeInterval(TimeInterval($0 * 300))) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date) -> TonightEntry {
        let n = Lock.night(around: date)
        // nights kept while the app was closed count before the app celebrates them
        let pending = Lock.keptPending
        return TonightEntry(date: date, bed: n.bed, wake: n.wake, resting: Lock.isBedtime(date),
                            streak: Lock.streak + pending, night: Lock.nightsKept + pending + 1,
                            wakeLabel: Lock.clock(Lock.wakeMinutes))
    }
}

struct TonightWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "tonight", provider: TonightProvider()) { entry in
            TonightWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    ZStack {
                        W.night
                        RadialGradient(colors: [W.glow.opacity(0.18), .clear], center: .bottom, startRadius: 0, endRadius: 160)
                    }
                }
        }
        .configurationDisplayName("tonight")
        .description("your countdown to bedtime and your streak.")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryInline])
    }
}

struct TonightWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TonightEntry

    private var big: String { entry.resting ? entry.wakeLabel : W.hm(entry.bed.timeIntervalSince(entry.date)) }
    private var label: String { entry.resting ? "resting until" : "bedtime in" }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(entry.resting ? "resting until \(entry.wakeLabel)" : "bedtime in \(big)")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(W.font(12)).widgetAccentable()
                Text(big).font(W.font(22, "Medium"))
                Text("\(entry.streak) \(entry.streak == 1 ? "night" : "nights") in a row").font(W.font(12))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    (Text("night ") + Text("\(entry.night)").foregroundColor(W.amber))
                        .font(W.font(13)).foregroundColor(W.muted)
                    Spacer()
                    MiniLogo(size: 22)
                }
                Spacer()
                Text(label).font(W.font(13)).foregroundColor(W.muted)
                Text(big).font(W.font(32)).tracking(-1.2).foregroundColor(W.ivory)
                    .minimumScaleFactor(0.6).lineLimit(1)
                (Text("\(entry.streak)").foregroundColor(W.amber) + Text(entry.streak == 1 ? " night in a row" : " nights in a row"))
                    .font(W.font(12)).foregroundColor(W.muted).padding(.top, 6)
            }
        }
    }
}

// MARK: - Live Activity

struct BedtimeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BedtimeActivity.self) { context in
            BedtimeBanner(context: context)
                .activityBackgroundTint(W.night)
                .activitySystemActionForegroundColor(W.ivory)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    MiniLogo(size: 30).padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(context).font(W.font(26)).foregroundColor(W.ivory).padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.isStale ? "resting until \(context.attributes.wakeLabel). tonight's star is waiting."
                                         : "your apps rest at \(context.attributes.bedLabel).")
                        .font(W.font(14)).foregroundColor(W.muted)
                }
            } compactLeading: {
                Image(systemName: "moon.fill").foregroundColor(W.amber)
            } compactTrailing: {
                countdown(context).font(W.font(14)).foregroundColor(W.ivory).frame(maxWidth: 52)
            } minimal: {
                Image(systemName: "moon.fill").foregroundColor(W.amber)
            }
            .keylineTint(W.amber)
        }
    }

    /// Counts down to bedtime; once stale (bedtime passed) it just says "resting".
    @ViewBuilder private func countdown(_ context: ActivityViewContext<BedtimeActivity>) -> some View {
        if context.isStale {
            Text("resting")
        } else {
            Text(timerInterval: min(Date(), context.attributes.bedtime)...context.attributes.bedtime, countsDown: true)
                .monospacedDigit().multilineTextAlignment(.trailing)
        }
    }
}

struct BedtimeBanner: View {
    let context: ActivityViewContext<BedtimeActivity>
    var body: some View {
        HStack(spacing: 14) {
            MiniLogo(size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(context.isStale ? "resting until \(context.attributes.wakeLabel)" : "bedtime in")
                    .font(W.font(14)).foregroundColor(W.muted)
                if !context.isStale {
                    Text(timerInterval: min(Date(), context.attributes.bedtime)...context.attributes.bedtime, countsDown: true)
                        .font(W.font(30)).monospacedDigit().foregroundColor(W.ivory)
                }
                Text(context.isStale ? "tonight's star is waiting." : "your apps rest at \(context.attributes.bedLabel).")
                    .font(W.font(13)).foregroundColor(W.muted)
            }
            Spacer()
        }
        .padding(18)
    }
}
