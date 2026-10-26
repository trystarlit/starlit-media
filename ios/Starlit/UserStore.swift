import SwiftUI

/// Everything we learn in onboarding, saved on the device with UserDefaults (no account in v1).
final class UserStore: ObservableObject {
    private let d = UserDefaults.standard

    @Published var onboarded: Bool { didSet { d.set(onboarded, forKey: "onboarded") } }
    @Published var name: String { didSet { d.set(name, forKey: "name") } }
    @Published var goals: Set<Goal> { didSet { d.set(goals.map(\.rawValue), forKey: "goals") } }
    /// Bedtime they want, minutes after midnight of the evening (23:00 = 1380). Values past 1440 mean after midnight.
    @Published var wantMinutes: Int { didSet { d.set(wantMinutes, forKey: "wantMinutes") } }
    /// What actually happens (1:30am = 1530).
    @Published var actualMinutes: Int { didSet { d.set(actualMinutes, forKey: "actualMinutes") } }
    @Published var wakeMinutes: Int { didSet { d.set(wakeMinutes, forKey: "wakeMinutes") } }
    @Published var mornings: String { didSet { d.set(mornings, forKey: "mornings") } }
    @Published var keepsUp: Set<String> { didSet { d.set(Array(keepsUp), forKey: "keepsUp") } }
    @Published var nightsKept: Int { didSet { d.set(nightsKept, forKey: "nightsKept") } }
    @Published var streak: Int { didSet { d.set(streak, forKey: "streak") } }
    @Published var bestStreak: Int { didSet { d.set(bestStreak, forKey: "bestStreak") } }

    init() {
        onboarded = d.bool(forKey: "onboarded")
        name = d.string(forKey: "name") ?? ""
        goals = Set((d.stringArray(forKey: "goals") ?? []).compactMap(Goal.init(rawValue:)))
        wantMinutes = d.object(forKey: "wantMinutes") as? Int ?? 23 * 60
        actualMinutes = d.object(forKey: "actualMinutes") as? Int ?? 25 * 60 + 30
        wakeMinutes = d.object(forKey: "wakeMinutes") as? Int ?? 7 * 60
        mornings = d.string(forKey: "mornings") ?? ""
        keepsUp = Set(d.stringArray(forKey: "keepsUp") ?? [])
        nightsKept = d.integer(forKey: "nightsKept")
        streak = d.integer(forKey: "streak")
        bestStreak = d.integer(forKey: "bestStreak")
    }

    /// The goal we personalize copy with (first one they picked, in display order).
    var topGoal: Goal { Goal.allCases.first(where: { goals.contains($0) }) ?? .rested }

    var displayName: String { name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

    /// Hours lost per night between the bedtime they want and the one that happens.
    var hoursLost: Double { max(0.5, Double(actualMinutes - wantMinutes) / 60.0) }
    var daysPerYear: Int { Int((hoursLost * 365 / 24).rounded()) }

    func reset() {
        onboarded = false; name = ""; goals = []; mornings = ""; keepsUp = []; nightsKept = 0; streak = 0; bestStreak = 0
    }

    /// A night was kept: one more star, streak +1.
    func keepNight() {
        nightsKept += 1; streak += 1; bestStreak = max(bestStreak, streak)
    }

    /// Kept a night on this weekday? (0 = monday). `keptThrough` is the last kept weekday index.
    func dayState(_ i: Int, today: Int, keptThrough: Int) -> DayState {
        if i <= keptThrough && i > keptThrough - streak { return .kept }
        if i < today { return .missed }
        return i == today ? .today : .future
    }

    static var weekdayIndex: Int { (Calendar.current.component(.weekday, from: Date()) + 5) % 7 }   // monday = 0

    static func ampm(_ minutes: Int) -> String { (((minutes % 1440) + 1440) % 1440) >= 720 ? "pm" : "am" }

    var displayNameOrYou: String { displayName.isEmpty ? "you" : displayName }

    static func clock(_ minutes: Int) -> String {
        let m = ((minutes % 1440) + 1440) % 1440
        let h = m / 60, mm = m % 60
        let h12 = h % 12 == 0 ? 12 : h % 12
        return mm == 0 ? "\(h12):00" : String(format: "%d:%02d", h12, mm)
    }
}

enum DayState { case kept, missed, today, future }

enum Goal: String, CaseIterable, Identifiable {
    case rested, scrolling, energy, focus, together
    var id: String { rawValue }

    var label: String {
        switch self {
        case .rested: return "wake up actually rested"
        case .scrolling: return "stop scrolling in bed"
        case .energy: return "more energy for the day"
        case .focus: return "focus better at school or work"
        case .together: return "feel like i have my life together"
        }
    }

    /// Paywall / how-it-works headline for this goal.
    var promise: String {
        switch self {
        case .rested: return "wake up rested"
        case .scrolling: return "put the phone down for real"
        case .energy: return "get your energy back"
        case .focus: return "show up sharp"
        case .together: return "get your nights back"
        }
    }
}
