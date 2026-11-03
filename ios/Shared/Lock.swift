import Foundation
#if !WIDGET
import FamilyControls
import ManagedSettings
import DeviceActivity
#endif
import WidgetKit

/// The Screen Time lock, shared by the app and its extensions through the app group.
/// The monitor extension calls `startNight` at bedtime and `endNight` at wake time.
/// The widget (no Family Controls entitlement) builds with WIDGET set and only sees the plain schedule/streak part.
enum Lock {
    static let defaults = UserDefaults(suiteName: "group.com.laith.starlit") ?? .standard

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

    /// When tonight's lock should end (the wake time after the bedtime it started for), set by `startNight`.
    static var lockUntil: Date? {
        get { let t = defaults.double(forKey: "lockUntil"); return t > 0 ? Date(timeIntervalSince1970: t) : nil }
        set { defaults.set(newValue?.timeIntervalSince1970 ?? 0, forKey: "lockUntil") }
    }

    /// The locked night has reached its wake time. `slack` lets an early wake-time callback through.
    static func nightIsOver(slack: TimeInterval = 0, now: Date = Date()) -> Bool {
        guard let until = lockUntil else { return !isBedtime(now) }   // locked before lockUntil existed
        return now >= until.addingTimeInterval(-slack)
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

#if !WIDGET
extension Lock {
    static let bedtime = DeviceActivityName("bedtime")
    /// A short interval starting at wake time: a second chance to unlock if iOS skips or rushes the bedtime end.
    static let morning = DeviceActivityName("morning")
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

    static func startNight() {
        guard hasApps, brokenNight != nightID() else { return }
        if !nightOpen { askUnlock = false }   // a new night starts with the plain shield
        nightOpen = true
        lockUntil = night().wake
        shield()
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func endNight() {
        // re-registering the schedule (e.g. after an app update) can end the interval mid-night, so only an end
        // at wake time counts; iOS can call this a little before wake time, so a few minutes early is fine
        guard nightIsOver(slack: 5 * 60) else { return }
        if nightOpen { keptPending += 1 }
        nightOpen = false
        settings.clearAllSettings()
        // the night is over: changes that had to wait for it start now
        if pendingBed != nil || pendingWake != nil {
            bedMinutes = pendingBed ?? bedMinutes; wakeMinutes = pendingWake ?? wakeMinutes
            pendingBed = nil; pendingWake = nil
            schedule()
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// A bedtime/wake change waiting for tonight to end (see `request`).
    static var pendingBed: Int? {
        get { defaults.object(forKey: "pendingBed") as? Int }
        set { defaults.set(newValue, forKey: "pendingBed") }
    }
    static var pendingWake: Int? {
        get { defaults.object(forKey: "pendingWake") as? Int }
        set { defaults.set(newValue, forKey: "pendingWake") }
    }

    /// From 2 hours before bedtime until wake time (or while resting), the schedule can only get stricter.
    static func guarded(_ date: Date = Date()) -> Bool {
        if nightOpen { return true }
        guard hasApps, defaults.string(forKey: "scheduled") != nil else { return false }   // first setup: nothing to dodge yet
        let calendar = Calendar.current.dateComponents([.hour, .minute], from: date)
        let now = (calendar.hour ?? 0) * 60 + (calendar.minute ?? 0)
        let from = (bedMinutes - 120 + 1440) % 1440
        return from <= wakeMinutes ? (now >= from && now < wakeMinutes) : (now >= from || now < wakeMinutes)
    }

    /// Sets the schedule the app asks for. Near or during the night, a later bedtime or an earlier wake time
    /// waits until the night ends, so the lock can't be dodged by moving it; stricter changes apply now.
    static func request(bed: Int, wake: Int) {
        guard guarded() else {
            bedMinutes = bed; wakeMinutes = wake; pendingBed = nil; pendingWake = nil
            return
        }
        let evening = { (m: Int) in (m - 12 * 60 + 1440) % 1440 }   // compare bedtimes from noon, so 1am is later than 11pm
        if evening(bed) > evening(bedMinutes) { pendingBed = bed } else { bedMinutes = bed; pendingBed = nil }
        if wake < wakeMinutes { pendingWake = wake } else { wakeMinutes = wake; pendingWake = nil }
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
            guard !nightOpen else { return }   // emptying the app list mid-night doesn't unlock tonight
            center.stopMonitoring([bedtime, morning])
            settings.clearAllSettings()
            defaults.removeObject(forKey: "scheduled")
            return
        }
        let s = DeviceActivitySchedule(intervalStart: DateComponents(hour: bedMinutes / 60, minute: bedMinutes % 60),
                                       intervalEnd: DateComponents(hour: wakeMinutes / 60, minute: wakeMinutes % 60),
                                       repeats: true)
        // re-registering mid-night can end the interval (and credit a fake kept night), so only when times change
        let key = "\(bedMinutes)-\(wakeMinutes)"
        let wakeEnd = (wakeMinutes + 20) % 1440   // iOS needs at least 15 minutes
        let m = DeviceActivitySchedule(intervalStart: DateComponents(hour: wakeMinutes / 60, minute: wakeMinutes % 60),
                                       intervalEnd: DateComponents(hour: wakeEnd / 60, minute: wakeEnd % 60),
                                       repeats: true)
        if defaults.string(forKey: "scheduled") != key || !center.activities.contains(bedtime) || !center.activities.contains(morning) {
            try? center.startMonitoring(bedtime, during: s)
            try? center.startMonitoring(morning, during: m)
            defaults.set(key, forKey: "scheduled")
        }
        // a night whose wake time passed without iOS ending it: unlock now (the night still counts)
        if nightOpen, nightIsOver() { endNight() }
        if isBedtime() { startNight() }
    }
}
#endif
