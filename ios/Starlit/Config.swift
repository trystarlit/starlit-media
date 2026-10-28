import Foundation

/// Public keys for RevenueCat and Supabase. Both are safe to ship in the app (they're the "public" / "anon" keys).
/// Left empty, that service is switched off and the app works exactly like before.
enum Config {
    /// RevenueCat → Project settings → API keys → the iOS "Public app-specific API key" (starts with appl_).
    static let revenueCatKey = ""
    /// The RevenueCat entitlement that unlocks starlit.
    static let entitlement = "pro"

    /// Supabase → Project Settings → API: Project URL (https://xxxx.supabase.co).
    static let supabaseURL = ""
    /// Supabase → Project Settings → API: the anon public key.
    static let supabaseAnonKey = ""

    static var hasRevenueCat: Bool { !revenueCatKey.isEmpty }
    static var hasSupabase: Bool { !supabaseURL.isEmpty && !supabaseAnonKey.isEmpty }
}
