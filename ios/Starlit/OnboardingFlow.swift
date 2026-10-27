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
                case .want: TimeStep(title: ("what time do you ", "want", " to sleep?"), sub: "scroll to pick. you can change it anytime.",
                                     options: .times(21 * 60, 25 * 60),            // 9:00pm – 1:00am
                                     value: $store.wantMinutes, next: go(.actual))
                case .actual: TimeStep(title: ("and what time does it ", "actually", " happen?"), sub: "be honest. nobody's judging.",
                                       options: .times(max(21 * 60 + 30, store.wantMinutes), 28 * 60),   // up to 4:00am
                                       value: $store.actualMinutes, next: go(.mirror))
                case .mirror: MirrorStep(next: go(.mornings))
                case .mornings: SingleChoiceStep(title: ("how do your ", "mornings", " feel right now?"),
                                                 options: ["wrecked", "tired", "okay", "great"],
                                                 icons: ["battery.0percent", "battery.25percent", "battery.75percent", "battery.100percent"],
                                                 value: $store.mornings, next: go(.keepsUp))
                case .keepsUp: KeepsUpStep(next: go(.how))
                case .how: HowItWorksStep(next: go(.wow))
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

            // progress bar + back (hidden on the full-bleed moments)
            if ![Step.splash, .wow, .commit, .paywall].contains(step) {
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
            Headline("first, what should we ", amber: "call", " you?").rise(0)
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
            Headline("what do you want from your ", amber: "nights", ", \(store.displayNameOrYou)?", size: 34).rise(0)
            Text("pick all that fit").font(Theme.font(15)).foregroundColor(Theme.muted).padding(.bottom, 8).rise(1)
            ForEach(Array(Goal.allCases.enumerated()), id: \.element) { i, g in
                OptionCard(title: g.label, selected: store.goals.contains(g), tick: true) {
                    if store.goals.contains(g) { store.goals.remove(g) } else { store.goals.insert(g) }
                }
                .rise(i + 2)
            }
            OptionCard(title: "all of the above", selected: store.goals.count == Goal.allCases.count, tick: true) {
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
    var icons: [String] = []   // SF Symbols, one per option
    @Binding var value: String
    var next: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Spacer()
            Headline(title.0, amber: title.1, title.2, size: 34).padding(.bottom, 16).rise(0)
            ForEach(Array(options.enumerated()), id: \.element) { i, o in
                OptionCard(title: o, selected: value == o, icon: icons.indices.contains(i) ? icons[i] : nil) {
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
    // Stand-in list. On a real phone this becomes Apple's FamilyActivityPicker once Family Controls is approved.
    static let apps = ["tiktok", "instagram", "youtube", "snapchat", "texting", "games", "netflix", "x"]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Spacer().frame(height: 50)
            Headline("what ", amber: "keeps", " you up?")
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { next() }
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

/// Placeholder paywall. Real purchases (RevenueCat/Superwall) come once the paid developer account is set up.
struct PaywallStep: View {
    @EnvironmentObject var store: UserStore
    var finish: () -> Void
    @State private var annual = true
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
            plan(title: "yearly · $39.99", sub: "7 days free, then $3.33/mo", badge: "best value", on: annual) { annual = true }
            plan(title: "monthly · $7.99", sub: "no free trial", badge: nil, on: !annual) { annual = false }
            HStack {
                Text("today: full access"); Spacer(); Text("day 5: reminder"); Spacer(); Text("day 7: trial ends")
            }
            .font(Theme.font(12)).foregroundColor(Theme.muted).padding(.horizontal, 4)
            PrimaryButton(title: annual ? "start my 7 free nights" : "continue", action: finish)
            Text(annual ? "7 days free, then $39.99/year. cancel anytime." : "$7.99/month. cancel anytime.")
                .font(Theme.font(12)).foregroundColor(Theme.muted).frame(maxWidth: .infinity)
            HStack(spacing: 18) {
                // TODO with RevenueCat: Purchases.shared.restorePurchases, then finish() if a subscription is active
                Button("restore") { Haptics.tap() }
                Link("terms", destination: Links.terms)
                Link("privacy", destination: Links.privacy)
            }
            .font(Theme.font(12)).foregroundColor(Theme.muted).frame(maxWidth: .infinity)
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
