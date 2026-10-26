import SwiftUI

@main
struct StarlitApp: App {
    @StateObject private var store = UserStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)   // v1 is dark only (app-decisions-1026)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: UserStore

    var body: some View {
        ZStack {
            Theme.night.ignoresSafeArea()
            if store.onboarded {
                HomeView()
                    .transition(.opacity)
            } else {
                OnboardingFlow()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: store.onboarded)
    }
}
