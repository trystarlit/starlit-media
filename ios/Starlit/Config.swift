import Foundation

/// Public keys for RevenueCat and Supabase. Both are safe to ship in the app (they're the "public" / "anon" keys).
/// Left empty, that service is switched off and the app works exactly like before.
enum Config {
    /// RevenueCat → Project settings → API keys → the iOS "Public app-specific API key" (starts with appl_).
    static let revenueCatKey = ""
    /// The RevenueCat entitlement that unlocks starlit.
    static let entitlement = "pro"

    /// Supabase → Project Settings → API: Project URL (https://xxxx.supabase.co).
    static let supabaseURL = "https://qkpirwxhbnrkbynofinh.supabase.co"
    /// Supabase → Project Settings → API Keys: the publishable key (sb_publishable_…), or the legacy anon key.
    static let supabaseAnonKey = "sb_publishable_F3TcFAf85TCMCm90Og-AeQ_lguwG4n6"

    static var hasRevenueCat: Bool { !revenueCatKey.isEmpty }
    static var hasSupabase: Bool { !supabaseURL.isEmpty && !supabaseAnonKey.isEmpty }
}
