import SwiftUI

/// Onboarding v2 (claude/build/app-decisions-1026.md):
/// problem → feel understood → how we solve it → wow moment → commit → (screen time + paywall come next).
struct OnboardingFlow: View {
    @EnvironmentObject var store: UserStore
    @State private var step = Step.splash
    @State private var paceChoice = 1

    enum Step: Int, CaseIterable {
        case splash, name, goals, want, actual, mirror, wake, mornings, keepsUp, windDown, pace, how, building, plan, future, wow, commit, paywall
    }

    var body: some View {
        ZStack {
            Theme.night.ignoresSafeArea()
            Group {
                switch step {
                case .splash: SplashStep(next: go(.name))
                case .name: NameStep(next: go(.goals))
                case .goals: GoalsStep(next: go(.want))
                case .want: TimeStep(title: ("what time do you ", "want", " to be asleep? 😴"), sub: "scroll to pick. you can change it anytime.",
                                     options: .bedtimes,
                                     value: $store.sleepMinutes, next: { store.actualMinutes = store.sleepMinutes; go(.actual)() })
                case .actual: TimeStep(title: ("and what time does it ", "actually", " happen? 👀"), sub: "be honest. nobody's judging.",
                                       options: .times(21 * 60, 29 * 60),   // 9:00pm – 5:00am; starts on their goal time
                                       value: $store.actualMinutes, next: go(.mirror))
                case .mirror: MirrorStep(next: go(.wake))
                case .wake: TimeStep(title: ("what time do you need to ", "wake up", "? ⏰"), sub: "your apps open again at this time. you can change it anytime.",
                                     options: .times(4 * 60 + 30, 11 * 60),
                                     value: $store.wakeMinutes, next: go(.mornings))
                case .mornings: SingleChoiceStep(title: ("how do your ", "mornings", " feel right now?"),
                                                 options: ["wrecked", "tired", "okay", "great"],
                                                 emojis: ["🧟", "🥱", "🙂", "☀️"],
                                                 value: $store.mornings, next: go(.keepsUp))
                case .keepsUp: KeepsUpStep(next: go(.windDown))
                case .windDown:
                    ChoiceStep(title: ("when should your phone go ", "down", "?"), sub: "that's when your apps lock.",
                               options: [("at bedtime · \(UserStore.clock(store.sleepMinutes))", "🛏️", 0),
                                         ("30 min before · \(UserStore.clock(store.sleepMinutes - 30))", "📖", 30),
                                         ("1 hour before · \(UserStore.clock(store.sleepMinutes - 60))", "🕯️", 60)],
                               value: $store.windDown,
                               header: { picked in
                                   AnyView(NightTimeline(lock: store.sleepMinutes - (picked ?? 0), sleep: store.sleepMinutes, wake: store.wakeMinutes))
                               },
                               next: { _ in
                                   if store.paceMakesSense { go(.pace)() } else { store.applyPlan(slow: false); go(.how)() }
                               })
                case .pace:
                    ChoiceStep(title: ("start slow or go ", "all in", "?"),
                               sub: "slow: \(UserStore.clock(store.paceStart)) tonight, 30 min earlier each week until \(UserStore.clock(store.planTarget)). all in: \(UserStore.clock(store.planTarget)) from tonight.",
                               options: [("start slow", "🐢", 1), ("all in", "🔥", 0)],
                               value: $paceChoice,
                               next: { v in store.applyPlan(slow: v == 1); go(.how)() })
                case .how: HowItWorksStep(next: go(.building))
                case .building: BuildingPlanStep(next: go(.plan))
                case .plan: PlanStep(next: go(.future))
                case .future: FutureStep(next: go(.wow))
                case .wow: WowStep(next: go(.commit))
                case .commit: CommitStep(next: go(.paywall))
                case .paywall: PaywallStep(finish: { store.onboarded = true })
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 34)
            .padding(.bottom, 16)
            .transition(.asymmetric(insertion: .opacity, removal: .opacity.combined(with: .offset(y: -6))))
            .id(step)
            .onAppear { Analytics.onboardingStep(step.rawValue, "\(step)") }
            .onChange(of: step) { _, s in Analytics.onboardingStep(s.rawValue, "\(s)") }

            // progress bar + back (hidden on the full-bleed moments)
            if ![Step.splash, .building, .wow, .commit, .paywall].contains(step) {
                VStack {
                    HStack(spacing: 12) {
                        Button { back() } label: {
                            Image(systemName: "chevron.left").foregroundColor(Theme.muted).font(.system(size: 17, weight: .medium))
                        }
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Theme.line)
                                Capsule().fill(Theme.amber).frame(width: g.size.width * CGFloat(step.rawValue) / CGFloat(Step.allCases.count - 1))
                            }
                        }
                        .frame(height: 3)
                    }
                    .padding(.horizontal, 28).padding(.top, 8)
                    Spacer()
                }
            }
        }
    }

    private func go(_ s: Step) -> () -> Void {
        { withAnimation(.easeOut(duration: 0.3)) { step = s } }
    }

    private func back() {
        guard var prev = Step(rawValue: step.rawValue - 1) else { return }
        if prev == .pace && !store.paceMakesSense { prev = .windDown }   // pace was skipped
        if prev == .building { prev = .how }   // the loader only plays going forward
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
            OrbitLogo(size: 64).padding(.bottom, 28).rise(0)
            Headline("get your ", amber: "nights", " back.", size: 40).rise(1)
            Text("a star for every night you put your phone down.")
                .font(Theme.font(16)).foregroundColor(Theme.muted).padding(.top, 12).padding(.bottom, 32).rise(2)
            PrimaryButton(title: "get started", action: next).rise(3)
        }
        .background(TwinkleSky(stars: 9, seed: 3, dust: 90, height: 0.45, amberLast: true).padding(-40).ignoresSafeArea())
    }
}

struct NameStep: View {
    @EnvironmentObject var store: UserStore
    var next: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer().frame(height: 60)
            Headline("first, what should we ", amber: "call", " you? 👋").rise(0)
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
            Button("skip") { Haptics.tap(); next() }
                .font(Theme.font(15)).foregroundColor(Theme.muted).frame(maxWidth: .infinity)
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
            Headline("what do you want from your ", amber: "nights", ", \(store.displayNameOrYou)?", size: 34).rise(0)
            Text("pick all that fit").font(Theme.font(15)).foregroundColor(Theme.muted).padding(.bottom, 8).rise(1)
            ForEach(Array(Goal.allCases.enumerated()), id: \.element) { i, g in
                OptionCard(title: "\(g.emoji)  \(g.label)", selected: store.goals.contains(g), tick: true) {
                    if store.goals.contains(g) { store.goals.remove(g) } else { store.goals.insert(g) }
                }
                .rise(i + 2)
            }
            OptionCard(title: "💯  all of the above", selected: store.goals.count == Goal.allCases.count, tick: true) {
                store.goals = store.goals.count == Goal.allCases.count ? [] : Set(Goal.allCases)
            }
            .rise(7)
            Spacer()
            PrimaryButton(title: "continue", enabled: !store.goals.isEmpty, action: next)
        }
    }
}

struct TimeStep: View {
    var title: (String, String, String)
    var sub: String
    var options: [Int]
    @Binding var value: Int
    var next: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Spacer().frame(height: 50)
            Headline(title.0, amber: title.1, title.2, size: 34).rise(0)
            Text(sub).font(Theme.font(15)).foregroundColor(Theme.muted).rise(1)
            Spacer()
            WheelPicker(values: options, selection: $value).rise(2)
            Spacer()
            PrimaryButton(title: "continue", action: next)
        }
        .onAppear { if !options.contains(value), let f = options.first { value = f } }
    }
}

struct SingleChoiceStep: View {
    var title: (String, String, String)
    var options: [String]
    var emojis: [String] = []   // one per option
    @Binding var value: String
    var next: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Spacer()
            Headline(title.0, amber: title.1, title.2, size: 34).padding(.bottom, 16).rise(0)
            ForEach(Array(options.enumerated()), id: \.element) { i, o in
                OptionCard(title: emojis.indices.contains(i) ? "\(emojis[i])  \(o)" : o, selected: value == o) {
                    value = o
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) { next() }
                }
                .rise(i + 1)
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
        let close = store.actualMinutes <= store.sleepMinutes
        VStack(alignment: .leading, spacing: 14) {
            Spacer()
            if close {
                Text("nice, \(store.displayNameOrYou)").font(Theme.font(15)).foregroundColor(Theme.muted)
                Headline("you're already ", amber: "close", ".", size: 40)
                Text("starlit keeps it that way, even on the nights your phone pulls you back in.")
                    .font(Theme.font(17)).foregroundColor(Theme.muted).fixedSize(horizontal: false, vertical: true)
                    .opacity(shown ? 1 : 0)
            } else {
                Text("every night, \(store.displayName)").font(Theme.font(15)).foregroundColor(Theme.muted)
                Headline("that's ", amber: hs, " a night.", size: 40)
                Text("about \(store.daysPerYear) days a year.")
                    .font(Theme.font(40)).tracking(-1.2).foregroundColor(Theme.muted)
                    .opacity(shown ? 1 : 0)
                YearDots(lost: store.daysPerYear, on: shown).padding(.top, 10)
                Text("each dot is a day. the amber ones are the sleep you lose to your phone.")
                    .font(Theme.font(13)).foregroundColor(Theme.muted).opacity(shown ? 1 : 0)
            }
            Spacer()
            PrimaryButton(title: close ? "continue" : "get them back", action: next)
        }
        .onAppear {
            Haptics.warning()
            withAnimation(.easeOut(duration: 0.8).delay(0.6)) { shown = true }
        }
    }
}

/// Their night on one line: phone down → asleep → wake up.
struct NightTimeline: View {
    var lock: Int
    var sleep: Int
    var wake: Int

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                point("lock", "🔒", lock, highlight: true)
                Spacer()
                point("asleep", "😴", sleep)
                Spacer()
                point("wake up", "☀️", wake)
            }
            GeometryReader { g in
                let span = Double(((wake - lock) % 1440 + 1440) % 1440)
                let sleepAt = span > 0 ? Double(((sleep - lock) % 1440 + 1440) % 1440) / span : 0
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.ivory.opacity(0.1))
                    Capsule().fill(LinearGradient(colors: [Theme.amber, Theme.glow.opacity(0.35)], startPoint: .leading, endPoint: .trailing))
                    Circle().fill(Theme.ivory).frame(width: 8, height: 8)
                        .offset(x: max(0, g.size.width * sleepAt - 4))
                }
            }
            .frame(height: 8)
            Text("your apps rest for the whole stretch").font(Theme.font(12)).foregroundColor(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16).card()
        .animation(.easeOut(duration: 0.3), value: lock)
    }

    private func point(_ label: String, _ emoji: String, _ minutes: Int, highlight: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(emoji).font(.system(size: 18))
            Text(UserStore.clock(minutes) + UserStore.ampm(minutes)).font(Theme.font(15)).monospacedDigit()
                .foregroundColor(highlight ? Theme.amber : Theme.ivory)
            Text(label).font(Theme.font(12)).foregroundColor(Theme.muted)
        }
    }
}

/// A year as 365 dots; the last `lost` light up amber, one after another.
struct YearDots: View {
    var lost: Int
    var on: Bool
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !on)) { tl in
            let t = on ? tl.date.timeIntervalSince(start) : 0
            Canvas { ctx, size in
                let cols = 26, rows = 15
                let step = min(size.width / CGFloat(cols), size.height / CGFloat(rows))
                let r = step * 0.28
                let lit = min(lost, Int(t / 0.04))
                for i in 0..<365 {
                    let x = (CGFloat(i % cols) + 0.5) * step, y = (CGFloat(i / cols) + 0.5) * step
                    let amber = i >= 365 - lit
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                             with: .color(amber ? Theme.amber : Theme.ivory.opacity(0.14)))
                }
            }
        }
        .frame(height: 190)
        .onChange(of: on) { _, v in if v { start = Date() } }
    }
}

/// One tap picks and moves on (the multiple-choice steps that change the plan).
struct ChoiceStep: View {
    var title: (String, String, String)
    var sub: String? = nil
    var options: [(label: String, emoji: String, value: Int)]
    @Binding var value: Int
    /// Optional picture under the subtitle; gets the picked value (nil before a tap).
    var header: ((Int?) -> AnyView)? = nil
    var next: (Int) -> Void
    @State private var picked: Int?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Spacer()
            Headline(title.0, amber: title.1, title.2, size: 34).rise(0)
            if let sub {
                Text(sub).font(Theme.font(15)).foregroundColor(Theme.muted).fixedSize(horizontal: false, vertical: true).rise(1)
            }
            if let header { header(picked).padding(.vertical, 10).rise(1) }
            Spacer().frame(height: 8)
            ForEach(Array(options.enumerated()), id: \.offset) { i, o in
                OptionCard(title: "\(o.emoji)  \(o.label)", selected: picked == o.value) {
                    guard picked == nil else { return }
                    picked = o.value
                    value = o.value
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) { next(o.value) }
                }
                .rise(i + 2)
            }
            Spacer().frame(height: 60)
        }
    }
}

/// Their answers, shown back as one plan before the wow moment.
struct PlanStep: View {
    @EnvironmentObject var store: UserStore
    var next: () -> Void
    @State private var visible = 0

    private var rows: [(String, String, String)] {
        let apps = store.keepsUp.sorted().prefix(3).joined(separator: ", ")
        let down = store.paceTarget > 0
            ? "\(UserStore.clock(store.wantMinutes)) tonight, then 30 min earlier each week to \(UserStore.clock(store.paceTarget))"
            : "\(UserStore.clock(store.wantMinutes))\(UserStore.ampm(store.wantMinutes)), every night"
        return [
            ("🌙", "phone down", down),
            ("⏰", "apps open again", "\(UserStore.clock(store.wakeMinutes))\(UserStore.ampm(store.wakeMinutes)), every morning"),
            ("📵", "resting", apps.isEmpty ? "the apps that keep you up" : apps),
            ("🛟", "rest nights", store.restPerWeek == 0 ? "none. no excuses." : "\(store.restPerWeek) a week, so one off night won't break your streak"),
            ("✨", "the payoff", "about \(store.daysPerYear) days back this year"),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer().frame(height: 50)
            Headline(store.displayName.isEmpty ? "your " : "\(store.displayName)'s ", amber: "plan", " is ready.", size: 34).rise(0)
            Text("built from your answers. you can change it anytime.").font(Theme.font(15)).foregroundColor(Theme.muted).rise(1)
            Spacer()
            ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                HStack(spacing: 14) {
                    Text(r.0).font(.system(size: 22)).frame(width: 40, height: 40)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.card2))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.1).font(Theme.font(15, .medium)).foregroundColor(Theme.ivory)
                        Text(r.2).font(Theme.font(13)).foregroundColor(Theme.muted).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12).card(18)
                .opacity(visible > i ? 1 : 0)
                .offset(y: visible > i ? 0 : 10)
            }
            Spacer()
            PrimaryButton(title: "this is my plan", action: next)
        }
        .onAppear {
            for i in 0..<5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + Double(i) * 0.28) {
                    Haptics.tap()
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { visible = i + 1 }
                }
            }
        }
    }
}

/// "building your plan…": checks off their answers one by one, then moves on by itself.
struct BuildingPlanStep: View {
    @EnvironmentObject var store: UserStore
    var next: () -> Void
    @State private var checked = 0
    @State private var progress = 0.0
    @State private var gone = false

    private var items: [String] {
        let apps = store.keepsUp.sorted().prefix(2).joined(separator: " + ")
        return [
            "phone down at \(UserStore.clock(store.wantMinutes))",
            "apps open at \(UserStore.clock(store.wakeMinutes))",
            apps.isEmpty ? "resting the apps that keep you up" : "resting \(apps)",
            store.restPerWeek == 0 ? "no excuses mode" : "\(store.restPerWeek) rest night\(store.restPerWeek == 1 ? "" : "s") a week",
            "\(store.displayName.isEmpty ? "your" : store.displayName + "'s") sky",
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()
            Headline("building your ", amber: "plan", "…", size: 34)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.line)
                    Capsule().fill(Theme.amber).frame(width: g.size.width * progress)
                }
            }
            .frame(height: 6)
            .padding(.bottom, 10)
            ForEach(Array(items.enumerated()), id: \.offset) { i, t in
                HStack(spacing: 12) {
                    ZStack {
                        Circle().stroke(checked > i ? Theme.amber : Theme.line, lineWidth: 1.5)
                        if checked > i {
                            Circle().fill(Theme.amber)
                            Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(Theme.night)
                        }
                    }
                    .frame(width: 22, height: 22)
                    Text(t).font(Theme.font(16)).foregroundColor(checked > i ? Theme.ivory : Theme.muted)
                }
                .scaleEffect(checked == i + 1 ? 1.02 : 1, anchor: .leading)
            }
            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3.1)) { progress = 1 }
            for i in 0..<5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45 + Double(i) * 0.55) {
                    Haptics.tap()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { checked = i + 1 }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.6) {
                guard !gone else { return }
                Haptics.success()
                next()
            }
        }
        .onDisappear { gone = true }
    }
}

/// "30 days from now": the outcome of their goals, with a sky filling up one star a night.
struct FutureStep: View {
    @EnvironmentObject var store: UserStore
    var next: () -> Void
    @State private var shown = 0

    private var lines: [String] {
        let goals = Goal.allCases.filter { store.goals.contains($0) }
        return Array((goals.isEmpty ? [.rested] : goals).prefix(3).map(\.outcome))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer().frame(height: 30)
            Label12("30 days from now").rise(0)
            Headline(store.displayName.isEmpty ? "your " : "\(store.displayName)'s ", amber: "sky", " in a month.", size: 34).rise(1)
            Text("30 nights kept. drag to look around.").font(Theme.font(15)).foregroundColor(Theme.muted).rise(2)
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(lines.enumerated()), id: \.offset) { i, l in
                    Text(l).font(Theme.font(17)).foregroundColor(Theme.ivory)
                        .opacity(shown > i ? 1 : 0).offset(y: shown > i ? 0 : 8)
                }
            }
            .allowsHitTesting(false)
            PrimaryButton(title: "i want that", action: next)
                .opacity(shown >= lines.count ? 1 : 0).padding(.top, 8)
        }
        .background(
            ZStack {
                Sky3DView(nights: 30)
                // keeps the outcome lines readable over the stars
                LinearGradient(colors: [.clear, Theme.night.opacity(0.85)], startPoint: .center, endPoint: .bottom)
                    .allowsHitTesting(false)
            }
            .padding(-40).ignoresSafeArea()
        )
        .onAppear {
            for i in 0..<lines.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2 + Double(i) * 0.45) {
                    Haptics.tap()
                    withAnimation(.easeOut(duration: 0.4)) { shown = i + 1 }
                }
            }
        }
    }
}

struct KeepsUpStep: View {
    @EnvironmentObject var store: UserStore
    var next: () -> Void
    // What keeps them up, in words. The real apps get picked in Apple's picker after the paywall (the tour).
    static let apps = ["tiktok", "instagram", "youtube", "snapchat", "texting", "games", "netflix", "x", "other"]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Spacer().frame(height: 50)
            Headline("what ", amber: "keeps", " you up? 📱")
            Text("we'll rest these at bedtime").font(Theme.font(15)).foregroundColor(Theme.muted).padding(.bottom, 8)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(Self.apps, id: \.self) { a in
                    OptionCard(title: a, selected: store.keepsUp.contains(a), tick: true) {
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
        let rows: [(String, String, String)] = [
            ("moon", "set your bedtime", "\(UserStore.clock(store.wantMinutes))\(UserStore.ampm(store.wantMinutes)), every night"),
            ("lock", "your phone rests", "\(store.keepsUp.sorted().prefix(3).joined(separator: ", ")) lock until morning"),
            ("star", "a star lights up", "every night you keep joins your sky"),
        ]
        VStack(alignment: .leading, spacing: 10) {
            Spacer().frame(height: 50)
            Headline("here's how you'll ", amber: store.topGoal.promise, ".", size: 34).rise(0)
            Spacer()
            ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                HStack(spacing: 16) {
                    Image(systemName: r.0).font(.system(size: 18)).foregroundColor(Theme.amber)
                        .frame(width: 44, height: 44).background(RoundedRectangle(cornerRadius: 14).fill(Theme.card2))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(r.1).font(Theme.font(17, .medium)).foregroundColor(Theme.ivory)
                        Text(r.2).font(Theme.font(14)).foregroundColor(Theme.muted)
                    }
                    Spacer(minLength: 0)
                }
                .padding(16).card(20)
                .opacity(visible > i ? 1 : 0)
                .offset(y: visible > i ? 0 : 10)
            }
            Spacer()
            PrimaryButton(title: "show me my sky", action: next)
        }
        .onAppear {
            for i in 0..<3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35 + Double(i) * 0.42) {
                    Haptics.tap()
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { visible = i + 1 }
                }
            }
        }
    }
}


/// The "wow" moment: full-screen sky, one empty slot. Tap it and night 1 lights up.
struct WowStep: View {
    @EnvironmentObject var store: UserStore
    var next: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var litAt: Date?
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 30)
            Label12("\(store.displayNameOrYou)'s sky").rise(0)
            Group {
                if litAt == nil {
                    Text("every night you keep becomes a star here.")
                } else {
                    Text("night ") + Text("1").foregroundColor(Theme.amber) + Text(" starts at \(UserStore.clock(store.wantMinutes)).")
                }
            }
            .font(Theme.font(32)).tracking(-1).multilineTextAlignment(.center).foregroundColor(Theme.ivory)
            .id(litAt == nil).transition(.opacity)
            .rise(1)
            Spacer()
            ZStack {
                if let litAt {
                    LitStar(start: litAt)
                } else {
                    Circle().stroke(Theme.amber.opacity(0.5), lineWidth: 1)
                        .frame(width: 46, height: 46).scaleEffect(pulse ? 2.4 : 0.8).opacity(pulse ? 0 : 0.8)
                    Circle().strokeBorder(Theme.amber.opacity(0.75), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .frame(width: 46, height: 46).scaleEffect(pulse ? 1.12 : 1)
                }
            }
            .frame(width: 220, height: 220)
            .contentShape(Circle().inset(by: 50))
            .onTapGesture {
                guard litAt == nil else { return }
                Haptics.star()
                withAnimation(.easeOut(duration: 0.5)) { litAt = Date() }
            }
            Group {
                if litAt == nil {
                    VStack(spacing: 6) {
                        Text("tap to light your first star").font(Theme.font(22)).foregroundColor(Theme.ivory)
                        Text("this is night 1").font(Theme.font(14)).foregroundColor(Theme.muted)
                    }
                } else {
                    Text("this is what keeping a night looks like.").font(Theme.font(14)).foregroundColor(Theme.muted)
                }
            }
            .frame(height: 56)
            Spacer()
            PrimaryButton(title: "i'm in", action: next)
                .opacity(litAt == nil ? 0 : 1).allowsHitTesting(litAt != nil)
                .animation(.easeOut(duration: 0.6).delay(0.5), value: litAt)
        }
        .background(TwinkleSky(stars: 0, seed: 12, dust: 120).padding(-40).ignoresSafeArea())
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: false)) { pulse = true }
        }
    }
}

/// The amber star blooming in, with a ripple ring.
struct LitStar: View {
    var start: Date
    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSince(start), c = CGPoint(x: size.width / 2, y: size.height / 2)
                let cx = Double(c.x), cy = Double(c.y)
                let k = min(1, t / 0.9), e = 1 - pow(1 - k, 3), bloom = sin(min(1, t / 0.8) * .pi)
                if t < 1.2 {
                    let r = 20 + t * 80
                    ctx.stroke(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                               with: .color(Theme.amber.opacity(0.6 * (1 - t / 1.2))), lineWidth: 1.5)
                }
                let breathe = t > 1 ? 0.06 * sin(t * 2) : 0
                ctx.glowDot(c, r: CGFloat(9 * e * (1 + 0.4 * bloom + breathe)), color: Theme.amber, alpha: e,
                            glowR: CGFloat((40 + 50 * bloom) * e), glowA: 0.5 + 0.3 * bloom)
            }
        }
    }
}

/// Hold to commit: stars spiral in and gather into one, the ring draws, and it becomes the orbit logo.
struct CommitStep: View {
    @EnvironmentObject var store: UserStore
    var next: () -> Void
    @State private var model = CommitModel()
    @State private var done = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Spacer().frame(height: 30)
            Group {
                if done {
                    VStack(alignment: .leading, spacing: 12) {
                        Headline("see you at ", amber: UserStore.clock(store.wantMinutes), ", \(store.displayNameOrYou).", size: 36)
                        Text("night 1 starts tonight.").font(Theme.font(15)).foregroundColor(Theme.muted)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Headline("i'll put my phone down at ", amber: UserStore.clock(store.wantMinutes), " tonight.", size: 36)
                        Text("press and hold the star to commit").font(Theme.font(15)).foregroundColor(Theme.muted)
                    }
                }
            }
            .id(done).transition(.opacity)
            Spacer()
            // no auto-advance: Apple's rating popup may be up, and it blocks this tap until it's gone
            if done {
                PrimaryButton(title: "continue", action: next).transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            TimelineView(.animation) { tl in
                Canvas { ctx, size in model.draw(ctx, size, tl.date) }
            }
            .padding(-40).ignoresSafeArea()
        )
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if model.doneAt == nil { model.holding = true } }
                .onEnded { _ in model.holding = false }
        )
        .onAppear {
            model.onDone = {
                DispatchQueue.main.async {
                    Haptics.success()
                    withAnimation(.easeOut(duration: 0.45)) { done = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { Analytics.askForRatingAfterCommit() }
                }
            }
        }
    }
}

final class CommitModel {
    var progress = 0.0, holding = false
    var doneAt: Date?
    var onDone: (() -> Void)?
    private var lastTick: Date?, lastBuzz = Date.distantPast
    private let stars: [(r0: Double, a0: Double, sz: Double, tw: Double)]
    private let dust: [SkyStar]

    init() {
        var r = Seeded(5)
        stars = (0..<34).map { _ -> (r0: Double, a0: Double, sz: Double, tw: Double) in (0.25 + r.next() * 0.9, r.next() * 6.283, 1.1 + r.next() * 1.9, r.next() * 6) }
        var r2 = Seeded(77)
        dust = (0..<60).map { _ in SkyStar(x: r2.next(), y: r2.next(), r: 0.4 + r2.next() * 1.1, phase: r2.next() * 6.28, speed: 0.4 + r2.next()) }
    }

    private func ease(_ v: Double) -> Double { v < 0.5 ? 4 * v * v * v : 1 - pow(-2 * v + 2, 3) / 2 }

    func draw(_ ctx: GraphicsContext, _ size: CGSize, _ now: Date) {
        let dt = min(0.05, now.timeIntervalSince(lastTick ?? now)); lastTick = now
        let t = now.timeIntervalSinceReferenceDate
        if doneAt == nil {
            progress = holding ? min(1, progress + dt / 2.0) : max(0, progress - dt / 0.6)
            if holding && now.timeIntervalSince(lastBuzz) > 0.14 - progress * 0.09 { Haptics.ramp(progress); lastBuzz = now }
            if progress >= 1 { doneAt = now; onDone?() }
        }
        let W = Double(size.width), H = Double(size.height)
        let cx = W / 2, cy = H - 230, R = max(W, H) * 0.7, e = ease(progress)
        for o in dust {
            ctx.glowDot(CGPoint(x: o.x * W, y: o.y * H), r: CGFloat(o.r), color: Theme.ivory, alpha: 0.1 + 0.08 * sin(t * o.speed + o.phase))
        }
        for s in stars {
            let rr = s.r0 * R * (1 - e), a = s.a0 + e * 2.6 + t * 0.05
            if doneAt != nil && rr < 1 { continue }
            let al = (0.45 + 0.35 * sin(t * 1.3 + s.tw)) * (1 - e * 0.2)
            ctx.glowDot(CGPoint(x: cx + cos(a) * rr, y: cy + sin(a) * rr * 0.9), r: CGFloat(s.sz * (1 - e * 0.35)), color: Theme.ivory, alpha: al)
        }
        let RR = 52.0, a1 = -23.5 * Double.pi / 180, a2 = 294 * Double.pi / 180
        let k = doneAt.map { min(1, now.timeIntervalSince($0) / 0.9) } ?? 0, ke = ease(k)
        let center = CGPoint(x: cx, y: cy)
        var track = Path(); track.addArc(center: center, radius: RR, startAngle: .zero, endAngle: .radians(2 * .pi), clockwise: false)
        ctx.stroke(track, with: .color(Theme.ivory.opacity(0.1)), lineWidth: 6)
        if progress > 0 {
            var arc = Path(); arc.addArc(center: center, radius: RR, startAngle: .radians(a1), endAngle: .radians(a1 + (a2 - a1) * e), clockwise: false)
            ctx.stroke(arc, with: .color(doneAt != nil ? Theme.ivory : Theme.amber), lineWidth: 6)
        }
        let la = -Double.pi / 4
        let sp = CGPoint(x: cx + cos(la) * 54 * ke, y: cy + sin(la) * 54 * ke)
        let sr = (6 + 7 * e) * (1 - 0.2 * ke)
        let bloom = doneAt.map { sin(min(1, now.timeIntervalSince($0) / 0.6) * .pi) } ?? 0
        ctx.glowDot(sp, r: CGFloat(sr), color: Theme.amber, glowR: CGFloat(sr * (5 + 7 * bloom)), glowA: 0.45 + 0.4 * bloom)
    }
}

/// Paywall. Purchases go through RevenueCat (Subscriptions); without a RevenueCat key the buttons just continue.
struct PaywallStep: View {
    @EnvironmentObject var store: UserStore
    @EnvironmentObject var subscriptions: Subscriptions
    var finish: () -> Void
    @State private var annual = true
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            OrbitLogo(size: 56).frame(maxWidth: .infinity).padding(.top, 6).rise(0)
            Headline("\(store.topGoal.promise), \(store.displayNameOrYou). ", amber: "7 nights", " free.", size: 32).rise(1)
            VStack(alignment: .leading, spacing: 12) {
                feature("moon", "your apps rest at \(UserStore.clock(store.wantMinutes)), so you do too")
                feature("sun.max", "wake up before your alarm")
                feature("star", "a sky that grows every night you keep")
            }
            .padding(.top, 6).rise(2)
            Spacer()
            plan(title: "yearly · \(subscriptions.annualPrice)", sub: "7 days free, then \(subscriptions.annualPerMonth)/mo", badge: "best value", on: annual) { annual = true }
            plan(title: "monthly · \(subscriptions.monthlyPrice)", sub: "no free trial", badge: nil, on: !annual) { annual = false }
            HStack {
                Text("today: full access"); Spacer(); Text("day 5: reminder"); Spacer(); Text("day 7: trial ends")
            }
            .opacity(annual ? 1 : 0)
            .font(Theme.font(12)).foregroundColor(Theme.muted).padding(.horizontal, 4)
            if Config.isTestFlight {
                Text("beta: free for testers. you won't be charged.")
                    .font(Theme.font(13, .medium)).foregroundColor(Theme.amber).frame(maxWidth: .infinity)
            }
            PrimaryButton(title: busy ? "one sec…" : annual ? "start my 7 free nights" : "continue", enabled: !busy) {
                run { try await subscriptions.purchase(annual: annual) }
            }
            Text(annual ? "7 days free, then \(subscriptions.annualPrice)/year. renews automatically until you cancel in Settings, at least 24 hours before it renews."
                        : "\(subscriptions.monthlyPrice)/month. renews automatically until you cancel in Settings, at least 24 hours before it renews.")
                .font(Theme.font(12)).foregroundColor(Theme.muted).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity)
            HStack(spacing: 18) {
                Button("restore") {
                    Haptics.tap()
                    run(nothingFound: "no subscription found on this apple id.") { try await subscriptions.restore() }
                }
                .disabled(busy)
                Link("terms", destination: Links.terms)
                Link("privacy", destination: Links.privacy)
                #if DEBUG
                Button("skip (debug)") { subscriptions.skipForTesting(); finish() }
                #endif
            }
            .font(Theme.font(12)).foregroundColor(Theme.muted).frame(maxWidth: .infinity)
        }
        .alert("hmm", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("ok", role: .cancel) {}
        } message: {
            Text(error ?? "")
        }
    }

    /// Runs a purchase/restore; finishes onboarding when it unlocks, shows an alert when it fails.
    private func run(nothingFound: String? = nil, _ action: @escaping () async throws -> Bool) {
        busy = true
        Task {
            defer { busy = false }
            do {
                if try await action() { finish() } else if let nothingFound { error = nothingFound }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func feature(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(Theme.amber).frame(width: 22)
            Text(text).font(Theme.font(16)).foregroundColor(Theme.ivory)
        }
    }

    private func plan(title: String, sub: String, badge: String?, on: Bool, tap: @escaping () -> Void) -> some View {
        Button { Haptics.select(); tap() } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Theme.font(16, .medium)).foregroundColor(Theme.ivory)
                    Text(sub).font(Theme.font(13)).foregroundColor(Theme.muted)
                }
                Spacer()
                if let badge {
                    Text(badge).font(Theme.font(11, .medium)).foregroundColor(Theme.night)
                        .padding(.horizontal, 8).padding(.vertical, 4).background(Capsule().fill(Theme.amber))
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 15)
            .background(RoundedRectangle(cornerRadius: 20).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(on ? Theme.amber : Theme.line, lineWidth: 1.5))
        }
        .buttonStyle(PressStyle())
    }
}
