import SwiftUI

/// After onboarding: tonight · sky · you, with a glass tab bar, plus full-screen moments
/// (resting, locked app, goodnight, morning, streak). The real lock (Screen Time) is wired in once Family Controls is approved.
enum AppTab: String, CaseIterable {
    case tonight, sky, you
    var icon: String {
        switch self {
        case .tonight: return "moon"
        case .sky: return "sparkles"
        case .you: return "person"
        }
    }
}

enum Moment: Equatable {
    case resting, shield(String), goodnight, morning, streak(justKept: Bool)
}

struct MainView: View {
    @EnvironmentObject var store: UserStore
    @State private var tab: AppTab = .tonight
    @State private var moment: Moment?
    @State private var litPending = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.night.ignoresSafeArea()
            Group {
                switch tab {
                case .tonight:
                    TonightTab(openSky: { switchTo(.sky) },
                               openStreak: { show(.streak(justKept: false)) },
                               restNow: { show(.resting) })
                case .sky:
                    SkyTab(newStar: litPending) {
                        litPending = false
                        show(.streak(justKept: true))
                    }
                case .you:
                    YouTab(preview: { show($0) })
                }
            }
            .id(tab)
            .transition(.opacity)

            GlassTabBar(tab: $tab)

            if let m = moment {
                momentView(m)
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
                    .zIndex(10)
            }
        }
        .animation(.easeOut(duration: 0.3), value: tab)
        .animation(.easeOut(duration: 0.4), value: moment)
    }

    private func switchTo(_ t: AppTab) { Haptics.tap(); tab = t }
    private func show(_ m: Moment?) { moment = m }

    @ViewBuilder private func momentView(_ m: Moment) -> some View {
        switch m {
        case .resting:
            RestingView(openApp: { show(.shield($0)) }, close: { show(nil) })
        case .shield(let app):
            ShieldView(app: app,
                       backToSleep: {
                           show(.goodnight)
                           DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { if moment == .goodnight { show(.resting) } }
                       },
                       unlocked: { store.missNight(); show(nil) })
        case .goodnight:
            GoodnightView()
        case .morning:
            MorningView {
                store.keepNight()
                litPending = true
                tab = .sky
                show(nil)
            }
        case .streak(let justKept):
            StreakView(justKept: justKept) { show(nil) }
        }
    }
}

// MARK: - tab bar

struct GlassTabBar: View {
    @Binding var tab: AppTab
    @Namespace private var ns
    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases, id: \.self) { t in
                Button {
                    guard tab != t else { return }
                    Haptics.select()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { tab = t }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: t.icon).font(.system(size: 17))
                        if tab == t { Text(t.rawValue).font(Theme.font(14)) }
                    }
                    .foregroundColor(tab == t ? Theme.ivory : Theme.muted)
                    .padding(.horizontal, 18).padding(.vertical, 11)
                    .background {
                        if tab == t { Capsule().fill(Theme.ivory.opacity(0.1)).matchedGeometryEffect(id: "pill", in: ns) }
                    }
                }
                .buttonStyle(PressStyle())
            }
        }
        .padding(6)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().stroke(Theme.ivory.opacity(0.1), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 15, y: 10)
        .padding(.bottom, 4)
    }
}

// MARK: - tonight

struct TonightTab: View {
    @EnvironmentObject var store: UserStore
    var openSky: () -> Void
    var openStreak: () -> Void
    var restNow: () -> Void
    @State private var sheet: SheetKind?

    enum SheetKind: String, Identifiable { case bed, wake, apps; var id: String { rawValue } }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                header.rise(0)
                hero.rise(1)
                HStack(spacing: 10) {
                    miniCard(top: "phone rests", value: "\(UserStore.clock(store.wantMinutes)) → \(UserStore.clock(store.wakeMinutes))", bottom: "tap to edit") { sheet = .bed }
                    miniCard(top: "resting apps", value: store.keepsUp.isEmpty ? "none" : "\(store.keepsUp.count)",
                             bottom: store.keepsUp.isEmpty ? "tap to pick" : store.keepsUp.sorted().prefix(2).joined(separator: ", ")) { sheet = .apps }
                }
                .rise(2)
                streakCard.rise(3)
                PrimaryButton(title: "rest now", action: restNow).rise(4)
            }
            .padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 110)
        }
        .sheet(item: $sheet) { k in
            switch k {
            case .bed: TimeSheet(title: "bedtime", values: .times(21 * 60, 25 * 60), value: $store.wantMinutes)
            case .wake: TimeSheet(title: "wake up", values: .times(5 * 60, 10 * 60), value: $store.wakeMinutes)
            case .apps: AppsSheet().environmentObject(store)
            }
        }
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        return h < 12 ? "good morning" : h < 18 ? "good afternoon" : "good evening"
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Label12("\(greeting), \(store.displayNameOrYou)")
                (Text("night ") + Text("\(store.nightsKept + 1)").foregroundColor(Theme.amber))
                    .font(Theme.font(24)).foregroundColor(Theme.ivory)
            }
            Spacer()
            OrbitLogo(size: 34)
        }
    }

    private var hero: some View {
        Button(action: openSky) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 30)
                    .fill(RadialGradient(colors: [Color(red: 42/255, green: 34/255, blue: 25/255), Color(red: 21/255, green: 18/255, blue: 15/255)],
                                         center: UnitPoint(x: 0.5, y: 1.2), startRadius: 0, endRadius: 420))
                TwinkleSky(stars: store.nightsKept + 1, seed: 41, dust: 80, height: 0.5)
                TimelineView(.periodic(from: .now, by: 30)) { ctx in
                    let m = minutesUntilBed(ctx.date)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(m > 16 * 60 ? "resting now" : "bedtime in").font(Theme.font(15)).foregroundColor(Theme.muted)
                        Text(m > 16 * 60 ? UserStore.clock(store.wakeMinutes) : "\(m / 60)h \(String(format: "%02d", m % 60))m")
                            .font(Theme.font(54, .light)).tracking(-2.4).monospacedDigit().foregroundColor(Theme.ivory)
                    }
                    .padding(20)
                }
            }
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 30))
            .overlay(RoundedRectangle(cornerRadius: 30).stroke(Theme.line, lineWidth: 1))
            .overlay(alignment: .topTrailing) {
                Text("your sky ›").font(Theme.font(12)).foregroundColor(Theme.muted)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(.ultraThinMaterial)).padding(16)
            }
        }
        .buttonStyle(PressStyle())
    }

    private func minutesUntilBed(_ d: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        let now = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        return ((store.wantMinutes % 1440) - now + 1440) % 1440
    }

    private func miniCard(top: String, value: String, bottom: String, tap: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); tap() } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(top).font(Theme.font(13)).foregroundColor(Theme.muted)
                Text(value).font(Theme.font(22)).tracking(-0.5).monospacedDigit().foregroundColor(Theme.ivory)
                Text(bottom).font(Theme.font(12)).foregroundColor(Theme.muted).lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .padding(16).card()
        }
        .buttonStyle(PressStyle())
    }

    private var streakCard: some View {
        Button { Haptics.tap(); openStreak() } label: {
            VStack(spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(store.streak)").font(Theme.font(22)).foregroundColor(Theme.amber)
                    Text("nights in a row").font(Theme.font(15)).foregroundColor(Theme.muted)
                    Spacer()
                    Text("best \(max(store.bestStreak, store.streak)) ›").font(Theme.font(15)).foregroundColor(Theme.muted)
                }
                WeekDots()
            }
            .padding(.horizontal, 14).padding(.vertical, 16).card()
        }
        .buttonStyle(PressStyle())
    }
}

struct WeekDots: View {
    @EnvironmentObject var store: UserStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    var body: some View {
        let today = UserStore.weekdayIndex
        HStack {
            ForEach(0..<7, id: \.self) { i in
                let st = store.dayState(i, today: today, keptThrough: today - 1)
                VStack(spacing: 8) {
                    ZStack {
                        switch st {
                        case .kept: Circle().fill(Theme.ivory).shadow(color: Theme.glow.opacity(0.35), radius: 5)
                        case .today: Circle().strokeBorder(Theme.amber, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])).scaleEffect(pulse ? 1.1 : 1)
                        default: Circle().strokeBorder(Theme.line, lineWidth: 1.5)
                        }
                    }
                    .frame(width: 22, height: 22)
                    Text(["m", "t", "w", "t", "f", "s", "s"][i]).font(Theme.font(12)).foregroundColor(Theme.muted)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever()) { pulse = true }
        }
    }
}

// MARK: - sky

struct SkyTab: View {
    @EnvironmentObject var store: UserStore
    var newStar: Bool
    var onLit: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Sky3DView(nights: store.nightsKept, newStar: newStar).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 6) {
                Label12("your sky")
                Headline("", amber: "\(store.nightsKept)", " nights kept.", size: 34)
                Text("drag to look around · tap a star").font(Theme.font(15)).foregroundColor(Theme.muted)
            }
            .padding(.horizontal, 22).padding(.top, 12)
            .allowsHitTesting(false)
            .rise(0)
        }
        .onAppear {
            guard newStar else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) { onLit() }
        }
    }
}

// MARK: - you

struct YouTab: View {
    @EnvironmentObject var store: UserStore
    var preview: (Moment) -> Void
    @State private var sheet: TonightTab.SheetKind?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    Text(String(store.displayNameOrYou.prefix(1))).font(Theme.font(22)).foregroundColor(Theme.amber)
                        .frame(width: 56, height: 56).background(Circle().fill(Theme.card2))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.displayNameOrYou).font(Theme.font(24)).foregroundColor(Theme.ivory)
                        Text(store.topGoal.label).font(Theme.font(15)).foregroundColor(Theme.muted)
                    }
                }
                .rise(0)
                HStack(spacing: 10) {
                    stat("\(store.nightsKept)", "nights kept")
                    stat("\(max(store.bestStreak, store.streak))", "best streak")
                    // estimate from their own onboarding answers, so it's labelled as one
                    stat("~\(Int(Double(store.nightsKept) * store.hoursLost))h", "hours back, est.")
                }
                .rise(1)
                Label12("your goals").padding(.top, 8)
                FlowChips(items: (store.goals.isEmpty ? [.rested] : Goal.allCases.filter { store.goals.contains($0) }).map(\.label))
                Label12("settings").padding(.top, 8)
                VStack(spacing: 0) {
                    row("bedtime", "\(UserStore.clock(store.wantMinutes))\(UserStore.ampm(store.wantMinutes))") { sheet = .bed }
                    row("wake up", "\(UserStore.clock(store.wakeMinutes))\(UserStore.ampm(store.wakeMinutes))") { sheet = .wake }
                    row("resting apps", "\(store.keepsUp.isEmpty ? "none" : "\(store.keepsUp.count)") ›") { sheet = .apps }
                    row("rest days left this week", "\(store.restDaysLeft)", last: true)
                }
                .card()
                Label12("preview screens").padding(.top, 8)
                VStack(spacing: 0) {
                    row("streak screen", "›") { preview(.streak(justKept: false)) }
                    row("locked app screen", "›") { preview(.shield(store.keepsUp.sorted().first ?? "tiktok")) }
                    row("morning: kept your night", "›") { preview(.morning) }
                    row("restart onboarding", "↺", last: true) { store.reset() }
                }
                .card()
            }
            .padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 110)
        }
        .sheet(item: $sheet) { k in
            switch k {
            case .bed: TimeSheet(title: "bedtime", values: .times(21 * 60, 25 * 60), value: $store.wantMinutes)
            case .wake: TimeSheet(title: "wake up", values: .times(5 * 60, 10 * 60), value: $store.wakeMinutes)
            case .apps: AppsSheet().environmentObject(store)
            }
        }
        .onAppear { store.refreshRestDays() }
    }

    private func stat(_ v: String, _ k: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(v).font(Theme.font(26)).tracking(-0.8).foregroundColor(Theme.ivory)
            Text(k).font(Theme.font(12)).foregroundColor(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14).card(20)
    }

    /// A settings row. Without `tap` it's plain info, not a button.
    @ViewBuilder private func row(_ title: String, _ value: String, last: Bool = false, tap: (() -> Void)? = nil) -> some View {
        if let tap {
            Button { Haptics.tap(); tap() } label: { rowLabel(title, value, last: last) }
                .buttonStyle(.plain)
        } else {
            rowLabel(title, value, last: last)
        }
    }

    private func rowLabel(_ title: String, _ value: String, last: Bool) -> some View {
        HStack {
            Text(title).foregroundColor(Theme.ivory)
            Spacer()
            Text(value).foregroundColor(Theme.muted)
        }
        .font(Theme.font(16))
        .padding(.horizontal, 18).padding(.vertical, 16)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { if !last { Rectangle().fill(Theme.line).frame(height: 1) } }
    }
}

/// Pick which apps rest at bedtime (stand-in for Apple's FamilyActivityPicker).
struct AppsSheet: View {
    @EnvironmentObject var store: UserStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("resting apps").font(Theme.font(24)).foregroundColor(Theme.ivory).padding(.top, 26)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(KeepsUpStep.apps, id: \.self) { a in
                    OptionCard(title: a, selected: store.keepsUp.contains(a), tick: true) {
                        if store.keepsUp.contains(a) { store.keepsUp.remove(a) } else { store.keepsUp.insert(a) }
                    }
                }
            }
            Spacer(minLength: 0)
            PrimaryButton(title: "done") { Haptics.success(); dismiss() }
        }
        .padding(.horizontal, 26).padding(.bottom, 10)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(red: 28/255, green: 25/255, blue: 21/255))
    }
}

/// Wrapping row of small pills.
struct FlowChips: View {
    var items: [String]
    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(items, id: \.self) { t in
                Text(t).font(Theme.font(13)).foregroundColor(Theme.ivory)
                    .padding(.horizontal, 11).padding(.vertical, 6).background(Capsule().fill(Theme.card2))
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let z = s.sizeThatFits(.unspecified)
            if x + z.width > w && x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += z.width + spacing; rowH = max(rowH, z.height)
        }
        return CGSize(width: w == .infinity ? x : w, height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let z = s.sizeThatFits(.unspecified)
            if x + z.width > bounds.maxX && x > bounds.minX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(z))
            x += z.width + spacing; rowH = max(rowH, z.height)
        }
    }
}
