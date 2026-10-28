import Foundation
import Combine
import Supabase

/// Backs up the user's onboarding answers, stars and streak to Supabase under an anonymous user (still no sign-in screen).
/// The anonymous session lives in the keychain, so after a delete + reinstall the same user comes back and we restore their sky.
/// Table + security rules: supabase/schema.sql.
@MainActor
final class Cloud {
    private let client: SupabaseClient?
    private var bag = Set<AnyCancellable>()

    init() {
        if Config.hasSupabase, let url = URL(string: Config.supabaseURL) {
            client = SupabaseClient(supabaseURL: url, supabaseKey: Config.supabaseAnonKey)
        } else {
            client = nil
        }
    }

    /// Sign in (anonymously), restore a backup onto a fresh install, then keep pushing changes.
    func start(store: UserStore, subscriptions: Subscriptions) async {
        guard let client else { return }
        let session: Session
        if let existing = try? await client.auth.session {
            session = existing
        } else {
            guard let fresh = try? await client.auth.signInAnonymously() else { return }
            session = fresh
        }
        let userID = session.user.id
        await subscriptions.logIn(userID.uuidString.lowercased())

        if !store.onboarded,
           let saved: Profile = try? await client.from("profiles").select().eq("id", value: userID).single().execute().value,
           saved.onboarded {
            saved.apply(to: store)
        }

        // objectWillChange fires before the value changes; the debounce reads it afterwards and batches quick edits.
        store.objectWillChange
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self, weak store] _ in
                guard let self, let store else { return }
                Task { await self.push(Profile(id: userID, store: store)) }
            }
            .store(in: &bag)
        await push(Profile(id: userID, store: store))
    }

    private func push(_ profile: Profile) async {
        _ = try? await client?.from("profiles").upsert(profile).execute()
    }
}

/// One row of the `profiles` table.
struct Profile: Codable {
    var id: UUID
    var onboarded: Bool
    var name: String
    var goals: [String]
    var wantMinutes: Int
    var actualMinutes: Int
    var wakeMinutes: Int
    var mornings: String
    var keepsUp: [String]
    var nightsKept: Int
    var streak: Int
    var bestStreak: Int
    var restDaysLeft: Int
    var restWeek: Int

    enum CodingKeys: String, CodingKey {
        case id, onboarded, name, goals, mornings, streak
        case wantMinutes = "want_minutes", actualMinutes = "actual_minutes", wakeMinutes = "wake_minutes"
        case keepsUp = "keeps_up", nightsKept = "nights_kept", bestStreak = "best_streak"
        case restDaysLeft = "rest_days_left", restWeek = "rest_week"
    }

    @MainActor init(id: UUID, store: UserStore) {
        self.id = id
        onboarded = store.onboarded; name = store.name; goals = store.goals.map(\.rawValue).sorted()
        wantMinutes = store.wantMinutes; actualMinutes = store.actualMinutes; wakeMinutes = store.wakeMinutes
        mornings = store.mornings; keepsUp = store.keepsUp.sorted()
        nightsKept = store.nightsKept; streak = store.streak; bestStreak = store.bestStreak
        restDaysLeft = store.restDaysLeft; restWeek = store.restWeek
    }

    @MainActor func apply(to store: UserStore) {
        store.name = name; store.goals = Set(goals.compactMap(Goal.init(rawValue:)))
        store.wantMinutes = wantMinutes; store.actualMinutes = actualMinutes; store.wakeMinutes = wakeMinutes
        store.mornings = mornings; store.keepsUp = Set(keepsUp)
        store.nightsKept = nightsKept; store.streak = streak; store.bestStreak = bestStreak
        store.restDaysLeft = restDaysLeft; store.restWeek = restWeek
        store.refreshRestDays()
        store.onboarded = onboarded
    }
}
