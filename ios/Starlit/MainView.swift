import SwiftUI
import FamilyControls

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
    @EnvironmentObject var subscriptions: Subscriptions
    @State private var tab: AppTab = .tonight
    @State private var moment: Moment?
    @State private var litPending = false
    @State private var welcome = false
    @State private var welcomeStart = 0
    #if DEBUG
    private static var shotUsed = false   // the screenshot switch applies to the first screen of a launch only
    #endif
    @State private var stop: TourStop?
    @State private var allSet = false
    @State private var stopRects: [TourStop: CGRect] = [:]
    @State private var askNow = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.night.ignoresSafeArea()
            Group {
                switch tab {
                case .tonight:
                    TonightTab(openSky: { switchTo(.sky) },
                               openStreak: { show(.streak(justKept: false)) },
                               restNow: {
                                   if store.screenTimeOK { Lock.startNight() }
                                   show(.resting)
                               },
                               focus: stop,
                               report: { stopRects[$0] = $1 })
                case .sky:
                    SkyTab(newStar: litPending) {
                        litPending = false
                        show(.streak(justKept: true))
                    }
                case .you:
                    YouTab(preview: { show($0) }, report: { stopRects[.you] = $0 })
                }
            }
            .id(tab)
            .transition(.opacity)

            GlassTabBar(tab: $tab)
                .allowsHitTesting(stop == nil)

            if let m = moment {
                momentView(m)
                    .allowsHitTesting(stop == nil)
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
                    .zIndex(10)
            }

            if let stop {
                Spotlight(stop: stop, rect: stop.spotlit ? stopRects[stop] : nil,
                          advance: { goTo(stop.next) }, skip: endTour)
                    .id(stop)
                    .transition(.opacity)
                    .zIndex(20)
            }

            if allSet {
                AllSetView(done: endTour)
                    .transition(.opacity)
                    .zIndex(25)
            }

            if welcome {
                WelcomeTour(start: welcomeStart) {
                    tab = .tonight
                    welcome = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { goTo(.skyCard) }
                }
                .transition(.opacity)
                .zIndex(30)
            }
        }
        .animation(.easeOut(duration: 0.3), value: tab)
        .animation(.easeOut(duration: 0.4), value: moment)
        .animation(.easeOut(duration: 0.35), value: stop)
        .animation(.easeInOut(duration: 0.5), value: allSet)
        .animation(.easeInOut(duration: 0.5), value: welcome)
        .onAppear {
            #if DEBUG
            // Launch with `-tourShot setup1` / `stop3` / `allset` to open the tour on that screen (for screenshots).
            // `-resetLockTest YES` undoes a lock test: gives back the rest night and lets tonight lock again
            if !Self.shotUsed, UserDefaults.standard.bool(forKey: "resetLockTest") {
                Lock.resetTestNight()
                store.restedDays.remove((UserStore.weekdayIndex + (Calendar.current.component(.hour, from: Date()) < 12 ? 6 : 0)) % 7)
                store.restDaysLeft = min(UserStore.maxRestDays, store.restDaysLeft + 1)
            }
            if !Self.shotUsed, let shot = UserDefaults.standard.string(forKey: "tourShot") {
                Self.shotUsed = true
                if shot.hasPrefix("setup") { welcomeStart = Int(shot.dropFirst(5)) ?? 0; welcome = true }
                else if shot.hasPrefix("stop"), let i = Int(shot.dropFirst(4)) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { goTo(TourStop.allCases[i]) }
                }
                else if shot == "allset" { allSet = true }
                else if shot == "streak" { moment = .streak(justKept: false) }
                return
            }
            #endif
            if !store.touredApp { welcome = true }
            checkLock()
        }
        .onChange(of: store.touredApp) { _, toured in
            if !toured && store.onboarded { moment = nil; welcome = true }
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { checkLock() } }
        .onChange(of: store.wantMinutes) { store.syncLock() }
        .onChange(of: store.wakeMinutes) { store.syncLock() }
        .onChange(of: store.selection) { store.syncLock() }
        .onChange(of: store.streak) { store.syncLock() }
        .onChange(of: store.nightsKept) { store.syncLock() }
        .onChange(of: moment) { _, m in if m == nil { askNow = false } }
    }

    /// Catches up with the lock: celebrates nights kept while the app was closed, or opens the
    /// unlock sheet when the shield's "i need it" sent us here.
    private func checkLock() {
        store.syncLock()
        subscriptions.scheduleTrialReminder()
        guard !welcome, stop == nil, !allSet else { return }
        let kept = Lock.keptPending
        if kept > 0 {
            Lock.keptPending = 0
            for _ in 1..<kept { store.keepNight() }   // the morning screen keeps the last one
            show(.morning)
        } else if Lock.askUnlock {
            Lock.askUnlock = false
            askNow = true
            show(.shield(""))
        }
    }

    /// Moves the tour to `s` (its tab and screen); nil means the walkthrough is over.
    private func goTo(_ s: TourStop?) {
        guard let s else { stop = nil; moment = nil; allSet = true; return }
        tab = s.tab
        moment = s.moment
        stop = s
    }

    private func endTour() {
        stop = nil; allSet = false; moment = nil; tab = .tonight
        store.touredApp = true
    }

    private func switchTo(_ t: AppTab) { Haptics.tap(); tab = t }
    private func show(_ m: Moment?) { moment = m }

    @ViewBuilder private func momentView(_ m: Moment) -> some View {
        switch m {
        case .resting:
            RestingView(previewNow: stop == .resting ? (store.wantMinutes + 75) % 1440 : nil,
                        openApp: { show(.shield($0)) },
                        close: { Lock.cancelEarlyRest(); show(nil) })
        case .shield(let app):
            ShieldView(app: app, askNow: askNow,
                       backToSleep: {
                           show(.goodnight)
                           DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { if moment == .goodnight { show(.resting) } }
                       },
                       unlocked: { store.missNight(); Lock.breakNight(); show(nil) })
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
            StreakView(justKept: justKept, report: { stopRects[.restNights] = $0 }) { show(nil) }
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
    var focus: TourStop? = nil
    var report: (TourStop, CGRect) -> Void = { _, _ in }
    @State private var sheet: SheetKind?

    enum SheetKind: String, Identifiable { case bed, wake, apps; var id: String { rawValue } }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                header.rise(0)
                hero.rise(1)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { report(.skyCard, $0) }
                    .id(TourStop.skyCard)
                HStack(spacing: 10) {
                    miniCard(top: "phone rests", value: "\(UserStore.clock(store.wantMinutes)) → \(UserStore.clock(store.wakeMinutes))", bottom: "tap to edit") { sheet = .bed }
                    miniCard(top: "resting apps", value: store.restingCount == 0 ? "none" : "\(store.restingCount)",
                             bottom: store.restingCount == 0 ? "tap to pick" : store.keepsUp.sorted().prefix(2).joined(separator: ", "),
                             icons: store.screenTimeOK && store.restingCount > 0) { sheet = .apps }
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { report(.appsCard, $0) }
                    .id(TourStop.appsCard)
                }
                .rise(2)
                streakCard.rise(3)
                PrimaryButton(title: "rest now", action: restNow).rise(4)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { report(.restNow, $0) }
                    .id(TourStop.restNow)
            }
            .padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 110)
        }
        .scrollDisabled(focus != nil)
        .onChange(of: focus) { _, f in
            guard let f else { return }
            withAnimation(.easeOut(duration: 0.35)) { proxy.scrollTo(f, anchor: .center) }
        }
        }
        .sheet(item: $sheet) { k in
            switch k {
            case .bed: TimeSheet(title: "bedtime", values: .bedtimes, value: $store.wantMinutes)
            case .wake: TimeSheet(title: "wake up", values: .wakeTimes, value: $store.wakeMinutes)
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
                TwinkleSky(stars: store.nightsKept, seed: 41, dust: 80, height: 0.5)
                TimelineView(.periodic(from: .now, by: 30)) { ctx in
                    let m = minutesUntilBed(ctx.date)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Lock.isBedtime(ctx.date) ? "resting until" : "bedtime in").font(Theme.font(15)).foregroundColor(Theme.muted)
                        Text(Lock.isBedtime(ctx.date) ? UserStore.clock(store.wakeMinutes) : "\(m / 60)h \(String(format: "%02d", m % 60))m")
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
            .overlay {
                VStack(spacing: 10) {
                    PendingStar(size: 52)
                    Text("tonight's star").font(Theme.font(12)).tracking(0.3).foregroundColor(Theme.muted)
                }
                .offset(x: 62, y: -42)
                .allowsHitTesting(false)
            }
        }
        .buttonStyle(PressStyle())
    }

    private func minutesUntilBed(_ d: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        let now = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        return ((store.wantMinutes % 1440) - now + 1440) % 1440
    }

    /// `icons` swaps the bottom line for the real icons of the resting apps.
    private func miniCard(top: String, value: String, bottom: String, icons: Bool = false, tap: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); tap() } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(top).font(Theme.font(13)).foregroundColor(Theme.muted)
                Text(value).font(Theme.font(22)).tracking(-0.5).monospacedDigit().foregroundColor(Theme.ivory)
                if icons {
                    RestingAppIcons(size: 16, limit: 5).frame(height: 16)
                } else {
                    Text(bottom).font(Theme.font(12)).foregroundColor(Theme.muted).lineLimit(1)
                }
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
                    Text(store.streak == 1 ? "night in a row" : "nights in a row").font(Theme.font(15)).foregroundColor(Theme.muted)
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

/// Tonight's star before it's earned: a dashed amber ring around a dim, breathing core.
struct PendingStar: View {
    var size: CGFloat = 34
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false
    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [Theme.amber.opacity(0.22), .clear], center: .center, startRadius: 0, endRadius: size / 2))
                .frame(width: size, height: size).scaleEffect(breathe ? 1.2 : 0.9)
            Circle().strokeBorder(Theme.amber.opacity(0.6), style: StrokeStyle(lineWidth: 1.2, dash: [2.5, 3.5]))
                .frame(width: size * 0.62, height: size * 0.62)
            Circle().fill(Theme.amber).frame(width: size * 0.13, height: size * 0.13)
                .shadow(color: Theme.glow.opacity(0.8), radius: breathe ? size * 0.18 : size * 0.08)
                .opacity(breathe ? 0.95 : 0.55)
        }
        .frame(width: size, height: size)
        .onAppear {
            guard !reduceMotion else { breathe = true; return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever()) { breathe = true }
        }
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
                        case .rested: RestDayIcon(size: 22)
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
    var report: (CGRect) -> Void = { _ in }
    @State private var sheet: TonightTab.SheetKind?
    @State private var confirmDelete = false
    @State private var liveCountdown = LiveBedtime.enabled
    @State private var deleteFailed = false
    @Environment(\.openURL) private var openURL

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
                    row("resting apps", "\(store.restingCount == 0 ? "none" : "\(store.restingCount)") ›") { sheet = .apps }
                    row("rest days saved", "\(store.restDaysLeft) of \(UserStore.maxRestDays)")
                    row("bedtime countdown on lock screen", liveCountdown ? "on" : "off", last: true) {
                        liveCountdown.toggle()
                        LiveBedtime.enabled = liveCountdown
                    }
                }
                .card()
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { report($0) }
                Label12("more").padding(.top, 8)
                VStack(spacing: 0) {
                    row("app tour", "›") { store.touredApp = false }
                    row("privacy policy", "↗") { openURL(Links.privacy) }
                    row("terms of use", "↗") { openURL(Links.terms) }
                    row("contact us", "↗") { openURL(Links.contact) }
                    row("delete my data", "", last: true) { confirmDelete = true }
                }
                .card()
                #if DEBUG
                Label12("preview screens (debug only)").padding(.top, 8)
                VStack(spacing: 0) {
                    row("streak screen", "›") { preview(.streak(justKept: false)) }
                    row("locked app screen", "›") { preview(.shield(store.keepsUp.sorted().first ?? "tiktok")) }
                    row("morning: kept your night", "›") { preview(.morning) }
                    row("restart onboarding", "↺", last: true) { store.reset() }
                }
                .card()
                #endif
            }
            .padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 110)
        }
        .sheet(item: $sheet) { k in
            switch k {
            case .bed: TimeSheet(title: "bedtime", values: .bedtimes, value: $store.wantMinutes)
            case .wake: TimeSheet(title: "wake up", values: .wakeTimes, value: $store.wakeMinutes)
            case .apps: AppsSheet().environmentObject(store)
            }
        }
        .onAppear { store.refreshRestDays() }
        .alert("delete my data?", isPresented: $confirmDelete) {
            Button("delete", role: .destructive) {
                Task {
                    guard await Cloud.shared.deleteEverything() else { deleteFailed = true; return }
                    store.selection = FamilyActivitySelection()
                    store.reset()
                }
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("this erases your sky, streak, answers and backup, and stops resting your apps. it can't be undone. your subscription stays active; manage it in the App Store.")
        }
        .alert("couldn't delete right now", isPresented: $deleteFailed) {
            Button("ok", role: .cancel) {}
        } message: {
            Text("check your connection and try again.")
        }
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
            ScrollView(showsIndicators: false) { RestingAppsPicker() }
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
