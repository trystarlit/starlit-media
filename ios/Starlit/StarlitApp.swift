import SwiftUI

@main
struct StarlitApp: App {
    @StateObject private var store = UserStore()
    @StateObject private var subscriptions = Subscriptions()
    private let cloud = Cloud.shared

    init() { Analytics.start() }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(subscriptions)
                .preferredColorScheme(.dark)   // v1 is dark only (app-decisions-1026)
                .task { await cloud.start(store: store, subscriptions: subscriptions) }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: UserStore
    @EnvironmentObject var subscriptions: Subscriptions

    var body: some View {
        ZStack {
            Theme.night.ignoresSafeArea()
            if store.onboarded && subscriptions.checked && !subscriptions.isActive {
                // hard paywall: onboarded but the subscription ended (or was never bought)
                PaywallStep(finish: {})
                    .padding(.horizontal, 28).padding(.top, 34).padding(.bottom, 16)
                    .transition(.opacity)
            } else if store.onboarded {
                MainView()
                    .transition(.opacity)
            } else {
                OnboardingFlow()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: store.onboarded)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)   // larger accessibility sizes would break the fixed-height cards
    }
}
