import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity
import WidgetKit

/// The Screen Time lock, shared by the app and its extensions through the app group.
/// The monitor extension calls `startNight` at bedtime and `endNight` at wake time.
enum Lock {
    static let defaults = UserDefaults(suiteName: "group.com.laith.starlit") ?? .standard
    static let bedtime = DeviceActivityName("bedtime")
    static let settings = ManagedSettingsStore(named: ManagedSettingsStore.Name("starlit"))

    static var selection: FamilyActivitySelection {
        get {
            guard let data = defaults.data(forKey: "selection"),
                  let s = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else { return FamilyActivitySelection() }
            return s
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: "selection") }
    }

    static var hasApps: Bool {
        let s = selection
        return !s.applicationTokens.isEmpty || !s.categoryTokens.isEmpty || !s.webDomainTokens.isEmpty
    }

    /// Minutes after midnight, 0..<1440.
    static var bedMinutes: Int {
        get { defaults.object(forKey: "bedMinutes") as? Int ?? 23 * 60 }
        set { defaults.set(newValue, forKey: "bedMinutes") }
    }
    static var wakeMinutes: Int {
        get { defaults.object(forKey: "wakeMinutes") as? Int ?? 7 * 60 }
        set { defaults.set(newValue, forKey: "wakeMinutes") }
    }

    /// Apps are resting tonight and nothing has been unlocked yet.
    static var nightOpen: Bool {
        get { defaults.bool(forKey: "nightOpen") }
        set { defaults.set(newValue, forKey: "nightOpen") }
    }
    /// Kept nights the app hasn't celebrated yet (set by the monitor at wake time).
    static var keptPending: Int {
        get { defaults.integer(forKey: "keptPending") }
        set { defaults.set(newValue, forKey: "keptPending") }
    }
    /// The shield's "i need it" button asks the app to open on the unlock sheet.
    static var askUnlock: Bool {
        get { defaults.bool(forKey: "askUnlock") }
        set { defaults.set(newValue, forKey: "askUnlock") }
    }
    /// The night (see `nightID`) that was unlocked, so it isn't locked again.
    private static var brokenNight: String? {
        get { defaults.string(forKey: "brokenNight") }
        set { defaults.set(newValue, forKey: "brokenNight") }
    }

    static func startNight() {
        guard hasApps, brokenNight != nightID() else { return }
        if !nightOpen { askUnlock = false }   // a new night starts with the plain shield
        nightOpen = true
        shield()
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func endNight() {
        if nightOpen { keptPending += 1 }
        nightOpen = false
        settings.clearAllSettings()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Unlocked tonight: the apps open until next bedtime and tonight's star stays dark.
    static func breakNight() {
        guard nightOpen || isBedtime() else { return }   // e.g. the "locked app" preview in the daytime
        nightOpen = false
        brokenNight = nightID()
        settings.clearAllSettings()
        WidgetCenter.shared.reloadAllTimelines()
    }

    #if DEBUG
    /// Undoes a test lock: tonight can lock again.
    static func resetTestNight() {
        brokenNight = nil; nightOpen = false; askUnlock = false; keptPending = 0
        settings.clearAllSettings()
    }
    #endif

    /// Stops an early "rest now" before bedtime, with no cost.
    static func cancelEarlyRest() {
        guard !isBedtime() else { return }
        nightOpen = false
        settings.clearAllSettings()
    }

    private static func shield() {
        let s = selection
        settings.shield.applications = s.applicationTokens.isEmpty ? nil : s.applicationTokens
        settings.shield.applicationCategories = s.categoryTokens.isEmpty ? nil : .specific(s.categoryTokens)
        settings.shield.webDomains = s.webDomainTokens.isEmpty ? nil : s.webDomainTokens
        settings.shield.webDomainCategories = s.categoryTokens.isEmpty ? nil : .specific(s.categoryTokens)
    }

    /// Re-registers the nightly schedule. Locks right away if it's already bedtime.
    static func schedule() {
        let center = DeviceActivityCenter()
        guard hasApps else {
            center.stopMonitoring([bedtime])
            settings.clearAllSettings()
            return
        }
        let s = DeviceActivitySchedule(intervalStart: DateComponents(hour: bedMinutes / 60, minute: bedMinutes % 60),
                                       intervalEnd: DateComponents(hour: wakeMinutes / 60, minute: wakeMinutes % 60),
                                       repeats: true)
        try? center.startMonitoring(bedtime, during: s)
        if isBedtime() { startNight() }
    }

    // For the widgets: the app publishes these whenever they change.
    static var streak: Int {
        get { defaults.integer(forKey: "streak") }
        set { defaults.set(newValue, forKey: "streak") }
    }
    static var nightsKept: Int {
        get { defaults.integer(forKey: "nightsKept") }
        set { defaults.set(newValue, forKey: "nightsKept") }
    }

    /// Tonight's bedtime and the wake time after it. While resting, it's the night already under way.
    static func night(around date: Date = Date()) -> (bed: Date, wake: Date) {
        let start = Calendar.current.startOfDay(for: date)
        var bed = start.addingTimeInterval(TimeInterval(bedMinutes * 60))
        if isBedtime(date) {
            if bed > date { bed.addTimeInterval(-86_400) }   // after midnight: it started yesterday
        } else if bed <= date {
            bed.addTimeInterval(86_400)
        }
        var wake = Calendar.current.startOfDay(for: bed).addingTimeInterval(TimeInterval(wakeMinutes * 60))
        if wake <= bed { wake.addTimeInterval(86_400) }
        return (bed, wake)
    }

    static func isBedtime(_ date: Date = Date()) -> Bool {
        let now = minutes(date)
        return bedMinutes <= wakeMinutes ? (now >= bedMinutes && now < wakeMinutes) : (now >= bedMinutes || now < wakeMinutes)
    }

    /// The evening a night belongs to: before wake time it's still last night.
    static func nightID(_ date: Date = Date()) -> String {
        let evening = minutes(date) < wakeMinutes ? date.addingTimeInterval(-86_400) : date
        let c = Calendar.current.dateComponents([.year, .month, .day], from: evening)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    static func clock(_ minutes: Int) -> String {
        let h = minutes / 60 % 24, m = minutes % 60
        return String(format: "%d:%02d", h % 12 == 0 ? 12 : h % 12, m)
    }

    private static func minutes(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}
