import Foundation
import PostHog
import StoreKit
import UIKit

/// Product analytics (PostHog). Anonymous only: an install id plus which step or action happened.
/// Never send the user's name, goals, bedtimes or picked apps.
enum Analytics {
    /// PostHog → Project settings → Project API key (public, safe to ship).
    static let key = "phc_pQvMLNB8GYHhQFUzjoeQCUNADAAb6Ufdb3j7sybtMbJm"
    static let host = "https://us.i.posthog.com"

    static func start() {
        #if DEBUG
        return
        #else
        let config = PostHogConfig(apiKey: key, host: host)
        config.captureScreenViews = false          // we send our own onboarding steps
        config.captureApplicationLifecycleEvents = true
        PostHogSDK.shared.setup(config)
        #endif
    }

    static func track(_ event: String, _ props: [String: Any] = [:]) {
        #if !DEBUG
        PostHogSDK.shared.capture(event, properties: props)
        #endif
    }

    /// One event per onboarding screen, in order, so PostHog can draw the funnel.
    static func onboardingStep(_ index: Int, _ name: String) {
        track("onboarding_step", ["step": index, "name": name])
    }

    /// Ask for an App Store rating once, after the 3rd kept night (Apple caps how often it really shows).
    @MainActor static func maybeAskForRating(nightsKept: Int) {
        let key = "askedForRating"
        guard nightsKept >= 3, !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        track("rating_prompt_shown")
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
        AppStore.requestReview(in: scene)
    }
}
