import SwiftUI

/// Onboarding v2 (claude/build/app-decisions-1026.md):
/// problem → feel understood → how we solve it → wow moment → commit → (screen time + paywall come next).
struct OnboardingFlow: View {
    @EnvironmentObject var store: UserStore
    @State private var step = Step.splash

    enum Step: Int, CaseIterable {
        case splash, name, goals, want, actual, mirror, mornings, keepsUp, how, wow, commit, paywall
    }

    var body: some View {
        ZStack {
            Theme.night.ignoresSafeArea()
            Group {
                switch step {
                case .splash: SplashStep(next: go(.name))
                case .name: NameStep(next: go(.goals))
                case .goals: GoalsStep(next: go(.want))
                case .want: TimeStep(title: ("what time do you ", "want", " to sleep?"),
                                     options: [22 * 60 + 30, 23 * 60, 23 * 60 + 30, 24 * 60],
                                     value: $store.wantMinutes, next: go(.actual))
                case .actual: TimeStep(title: ("and what time does it ", "actually", " happen?"),
                                       options: [23 * 60 + 30, 24 * 60 + 30, 25 * 60 + 30, 26 * 60],
                                       value: $store.actualMinutes, next: go(.mirror))
                case .mirror: MirrorStep(next: go(.mornings))
                case .mornings: SingleChoiceStep(title: ("how do your ", "mornings", " feel right now?"),
                                                 options: ["wrecked", "tired", "okay", "great"],
                                                 value: $store.mornings, next: go(.keepsUp))
                case .keepsUp: KeepsUpStep(next: go(.how))
                case .how: HowItWorksStep(next: go(.wow))
                case .wow: WowStep(next: go(.commit))
                case .commit: CommitStep(next: go(.paywall))
                case .paywall: PaywallStep(finish: { store.onboarded = true })
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
            .padding(.bottom, 24)
            .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 12)), removal: .opacity))
            .id(step)

            // progress dots + back
            if step != .splash {
                VStack {
                    HStack(spacing: 12) {
                        Button { back() } label: {
                            Image(systemName: "chevron.left").foregroundColor(Theme.muted).font(.system(size: 17, weight: .medium))
                        }
                        ProgressView(value: Double(step.rawValue), total: Double(Step.allCases.count - 1))
                            .tint(Theme.amber)
                    }
                    .padding(.horizontal, 28).padding(.top, 8)
                    Spacer()
                }
            }
        }
    }

    private func go(_ s: Step) -> () -> Void {
        { withAnimation(.easeOut(duration: 0.35)) { step = s } }
    }

    private func back() {
        guard let prev = Step(rawValue: step.rawValue - 1) else { return }
        Haptics.tap()
        withAnimation(.easeOut(duration: 0.3)) { step = prev }
    }
}

// MARK: - Steps

struct SplashStep: View {
    var next: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            OrbitLogo(size: 72).padding(.bottom, 36)
            Headline("get your ", amber: "nights", " back.", size: 42)
            Text("a star for every night you put your phone down.")
                .font(Theme.font(16)).foregroundColor(Theme.muted).padding(.top, 14).padding(.bottom, 40)
            PrimaryButton(title: "start", action: next)
        }
    }
}

struct NameStep: View {
    @EnvironmentObject var store: UserStore
    var next: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer().frame(height: 60)
            Headline("first, what should we ", amber: "call", " you?")
            TextField("", text: $store.name, prompt: Text("your name").foregroundColor(Theme.muted))
                .font(Theme.font(28))
                .foregroundColor(Theme.ivory)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($focused)
                .submitLabel(.continue)
                .onSubmit { if !store.displayName.isEmpty { next() } }
                .padding(.vertical, 14)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
            Spacer()
            PrimaryButton(title: "continue", enabled: !store.displayName.isEmpty, action: next)
        }
        .onAppear { focused = true }
    }
}

struct GoalsStep: View {
    @EnvironmentObject var store: UserStore
    var next: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Spacer().frame(height: 50)
            Headline("what do you want from your ", amber: "nights", ", \(store.displayName)?", size: 34)
            Text("pick all that fit").font(Theme.font(15)).foregroundColor(Theme.muted).padding(.bottom, 8)
            ForEach(Goal.allCases) { g in
                OptionCard(title: g.label, selected: store.goals.contains(g)) {
                    if store.goals.contains(g) { store.goals.remove(g) } else { store.goals.insert(g) }
                }
            }
            OptionCard(title: "all of the above", selected: store.goals.count == Goal.allCases.count) {
                store.goals = store.goals.count == Goal.allCases.count ? [] : Set(Goal.allCases)
            }
            Spacer()
            PrimaryButton(title: "continue", enabled: !store.goals.isEmpty, action: next)
        }
    }
}

struct TimeStep: View {
    var title: (String, String, String)
    var options: [Int]
    @Binding var value: Int
    var next: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer()
            Headline(title.0, amber: title.1, title.2)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(options, id: \.self) { m in
                    OptionCard(title: UserStore.clock(m) + (m == options.last && m >= 26 * 60 ? "+" : ""), selected: value == m) {
                        value = m
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { next() }
                    }
                }
            }
            Spacer().frame(height: 80)
        }
    }
}

struct SingleChoiceStep: View {
    var title: (String, String, String)
    var options: [String]
    @Binding var value: String
    var next: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Spacer()
            Headline(title.0, amber: title.1, title.2).padding(.bottom, 16)
            ForEach(options, id: \.self) { o in
                OptionCard(title: o, selected: value == o) {
                    value = o
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { next() }
                }
            }
            Spacer().frame(height: 60)
        }
    }
}

struct MirrorStep: View {
    @EnvironmentObject var store: UserStore
    var next: () -> Void
    @State private var shown = false
    var body: some View {
        let h = store.hoursLost
        let hs = h == 1 ? "1 hour" : (h.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(h)) hours" : String(format: "%.1f hours", h))
        VStack(alignment: .leading, spacing: 14) {
            Spacer()
            Text("every night, \(store.displayName)").font(Theme.font(15)).foregroundColor(Theme.muted)
            Headline("that's ", amber: hs, " a night.", size: 40)
            Text("about \(store.daysPerYear) days a year.")
                .font(Theme.font(40)).tracking(-1.2).foregroundColor(Theme.muted)
                .opacity(shown ? 1 : 0)
            Spacer()
            PrimaryButton(title: "get them back", action: next)
        }
        .onAppear {
            Haptics.warning()
            withAnimation(.easeOut(duration: 0.8).delay(0.6)) { shown = true }
        }
    }
}

struct KeepsUpStep: View {
    @EnvironmentObject var store: UserStore
    var next: () -> Void
    let apps = ["tiktok", "instagram", "youtube", "snapchat", "texting", "games"]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Spacer().frame(height: 50)
            Headline("what ", amber: "keeps", " you up?")
            Text("we'll rest these at bedtime").font(Theme.font(15)).foregroundColor(Theme.muted).padding(.bottom, 8)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(apps, id: \.self) { a in
                    OptionCard(title: a, selected: store.keepsUp.contains(a)) {
                        if store.keepsUp.contains(a) { store.keepsUp.remove(a) } else { store.keepsUp.insert(a) }
                    }
                }
            }
            Spacer()
            PrimaryButton(title: "continue", enabled: !store.keepsUp.isEmpty, action: next)
        }
    }
}

struct HowItWorksStep: View {
    @EnvironmentObject var store: UserStore
    var next: () -> Void
    @State private var visible = 0
    var body: some View {
        let rows: [(String, String)] = [
            ("set your bedtime", "\(UserStore.clock(store.wantMinutes)), every night"),
            ("your phone rests", "\(store.keepsUp.sorted().prefix(3).joined(separator: ", ")) lock until morning"),
            ("a star lights up", "every night you keep becomes part of your sky"),
        ]
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Headline("here's how you'll ", amber: store.topGoal.promise, ".", size: 34).padding(.bottom, 14)
            ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                HStack(alignment: .top, spacing: 14) {
                    Text("\(i + 1)").font(Theme.font(15, .medium)).foregroundColor(Theme.amber).frame(width: 18)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(r.0).font(Theme.font(20, .medium)).foregroundColor(Theme.ivory)
                        Text(r.1).font(Theme.font(15)).foregroundColor(Theme.muted)
                    }
                }
                .opacity(visible > i ? 1 : 0)
                .offset(y: visible > i ? 0 : 10)
            }
            Spacer()
            PrimaryButton(title: "show me", action: next)
        }
        .onAppear {
            for i in 0..<3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + Double(i) * 0.45) {
                    Haptics.tap()
                    withAnimation(.easeOut(duration: 0.4)) { visible = i + 1 }
                }
            }
        }
    }
}

/// The "wow" moment: their own sky, with their name, before any price.
struct WowStep: View {
    @EnvironmentObject var store: UserStore
    var next: () -> Void
    @State private var lit = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer().frame(height: 40)
            Text("\(store.displayName)'s sky").font(Theme.font(15)).foregroundColor(Theme.muted)
            Headline("night ", amber: "1", " starts at \(UserStore.clock(store.wantMinutes)).", size: 36)
            ZStack {
                RoundedRectangle(cornerRadius: 28).fill(Theme.card)
                SkyView(nights: 0, tonightLit: lit, showTonightSlot: true, seed: UInt64(abs(store.displayName.hashValue % 997) + 3))
                    .padding(10)
                VStack {
                    Spacer()
                    Text(lit ? "this is what keeping a night looks like." : "tap your first star")
                        .font(Theme.font(14)).foregroundColor(Theme.muted).padding(.bottom, 16)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                guard !lit else { return }
                Haptics.star()
                withAnimation(.spring(response: 0.6, dampingFraction: 0.55)) { lit = true }
            }
            PrimaryButton(title: "i'm in", enabled: lit, action: next)
        }
    }
}

/// Hold the star to commit: a small investment right before the paywall, with a haptic ramp.
struct CommitStep: View {
    @EnvironmentObject var store: UserStore
    var next: () -> Void
    @State private var progress: Double = 0
    @State private var holding = false
    @State private var done = false
    let timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer()
            if done {
                Headline("see you at ", amber: UserStore.clock(store.wantMinutes), ", \(store.displayName).")
                    .transition(.opacity)
            } else {
                Headline("i'll put my phone down at ", amber: UserStore.clock(store.wantMinutes), ".")
                Text("hold the star to commit").font(Theme.font(15)).foregroundColor(Theme.muted)
            }
            Spacer()
            ZStack {
                Circle().stroke(Theme.line, lineWidth: 4).frame(width: 120, height: 120)
                Circle().trim(from: 0, to: progress)
                    .stroke(done ? Theme.ivory : Theme.amber, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 120, height: 120)
                Circle().fill(Theme.amber)
                    .frame(width: 22 + 26 * progress, height: 22 + 26 * progress)
                    .shadow(color: Theme.glow.opacity(0.8), radius: 10 + 20 * progress)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 60)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in if !done { holding = true } }
                    .onEnded { _ in holding = false }
            )
        }
        .onReceive(timer) { _ in
            guard !done else { return }
            if holding {
                progress = min(1, progress + 1.0 / (1.8 * 30))
                if Int(progress * 30) % 3 == 0 { Haptics.ramp(progress) }
                if progress >= 1 {
                    done = true
                    Haptics.success()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { next() }
                }
            } else {
                progress = max(0, progress - 1.0 / (0.5 * 30))
            }
        }
        .animation(.easeOut(duration: 0.4), value: done)
    }
}

/// Placeholder paywall. Real purchases (RevenueCat/Superwall) come once the paid developer account is set up.
struct PaywallStep: View {
    @EnvironmentObject var store: UserStore
    var finish: () -> Void
    @State private var annual = true
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer().frame(height: 30)
            Headline("\(store.topGoal.promise), \(store.displayName). ", amber: "7 nights", " free.", size: 34)
            VStack(alignment: .leading, spacing: 10) {
                Label("your apps rest at \(UserStore.clock(store.wantMinutes)), so you do too", systemImage: "moon.stars")
                Label("wake up before your alarm", systemImage: "sunrise")
                Label("a sky that grows every night you keep", systemImage: "sparkles")
            }
            .font(Theme.font(16)).foregroundColor(Theme.ivory).padding(.vertical, 10)
            Spacer()
            OptionCard(title: "yearly · $39.99 · 7 days free, then $3.33/mo", selected: annual) { annual = true }
            OptionCard(title: "monthly · $7.99", selected: !annual) { annual = false }
            Text("today: full access · day 5: we remind you · day 7: trial ends")
                .font(Theme.font(12)).foregroundColor(Theme.muted).padding(.top, 4)
            PrimaryButton(title: annual ? "start my 7 free nights" : "continue", action: finish)
            Text("cancel anytime · no charge today (purchases not wired up yet)")
                .font(Theme.font(12)).foregroundColor(Theme.muted).frame(maxWidth: .infinity)
        }
    }
}
