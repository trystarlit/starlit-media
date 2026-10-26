import SwiftUI

/// Home / tonight. The real bedtime lock (Screen Time APIs) gets wired in once the paid developer account exists.
struct HomeView: View {
    @EnvironmentObject var store: UserStore
    @State private var now = Date()
    @State private var demoLit = false
    let tick = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var minutesUntilBed: Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: now)
        let nowM = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        return ((store.wantMinutes % 1440) - nowM + 1440) % 1440
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("tonight · night \(store.nightsKept + 1)").font(Theme.font(13)).foregroundColor(Theme.muted)
                Spacer()
                OrbitLogo(size: 26)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("bedtime in").font(Theme.font(15)).foregroundColor(Theme.muted)
                Text("\(minutesUntilBed / 60)h \(String(format: "%02d", minutesUntilBed % 60))m")
                    .font(Theme.font(56, .light)).tracking(-2).foregroundColor(Theme.ivory)
                    .monospacedDigit()
                Text("phone rests \(UserStore.clock(store.wantMinutes)) → \(UserStore.clock(store.wakeMinutes))")
                    .font(Theme.font(15)).foregroundColor(Theme.muted)
            }
            ZStack {
                RoundedRectangle(cornerRadius: 26).fill(Theme.card)
                SkyView(nights: store.nightsKept, tonightLit: demoLit, seed: 41).padding(10)
            }
            .frame(height: 240)
            .onTapGesture(count: 3) {           // dev shortcut: triple-tap the sky to fake keeping a night
                Haptics.star()
                withAnimation(.spring(response: 0.6, dampingFraction: 0.55)) { demoLit = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    store.nightsKept += 1; store.streak += 1; demoLit = false
                }
            }
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(store.streak) nights kept").font(Theme.font(22)).foregroundColor(Theme.ivory)
                    Text("in a row").font(Theme.font(14)).foregroundColor(Theme.muted)
                }
                Spacer()
                HStack(spacing: 7) {
                    ForEach(0..<7, id: \.self) { i in
                        Circle()
                            .fill(i < min(store.streak, 7) ? Theme.ivory : Theme.ivory.opacity(0.18))
                            .frame(width: 9, height: 9)
                    }
                }
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 26).fill(Theme.card))
            Spacer()
            Button("reset onboarding (dev)") { store.reset() }
                .font(Theme.font(12)).foregroundColor(Theme.muted).frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 24).padding(.top, 16)
        .onReceive(tick) { now = $0 }
    }
}
