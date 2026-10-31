import Foundation

/// Public keys for RevenueCat and Supabase. Both are safe to ship in the app (they're the "public" / "anon" keys).
/// Left empty, that service is switched off and the app works exactly like before.
enum Config {
    /// RevenueCat → API keys → SDK API keys → the "starlit" App Store app (public, safe to ship).
    /// The Test Store key (test_YplEMSVWzQrBcQHFipisEjibNsw) only makes fake purchases; never ship it.
    static let revenueCatKey = "appl_mGzqxBUTEJRfpMysbjnWZEPFcxm"

    /// Supabase → Project Settings → API: Project URL (https://xxxx.supabase.co).
    static let supabaseURL = "https://qkpirwxhbnrkbynofinh.supabase.co"
    /// Supabase → Project Settings → API Keys: the publishable key (sb_publishable_…), or the legacy anon key.
    static let supabaseAnonKey = "sb_publishable_F3TcFAf85TCMCm90Og-AeQ_lguwG4n6"

    /// TestFlight beta: everything is free for testers, so RevenueCat stays off.
    /// Only in builds compiled with the BETA flag (Other Swift Flags: -D BETA). App Review also runs on a
    /// sandbox receipt, so an App Store build must never take this path or reviewers can't see the subscription.
    static let isTestFlight: Bool = {
        #if BETA
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #else
        return false
        #endif
    }()

    static var hasRevenueCat: Bool { !revenueCatKey.isEmpty && !isTestFlight }
    static var hasSupabase: Bool { !supabaseURL.isEmpty && !supabaseAnonKey.isEmpty }
}
