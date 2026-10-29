import SwiftUI
import FamilyControls
import UserNotifications

/// Shown once, right after the first purchase: welcome → screen time → resting apps.
/// Then MainView walks through the app stop by stop (`TourStop` + `Spotlight`) and ends on `AllSetView`.
struct WelcomeTour: View {
    @EnvironmentObject var store: UserStore
    var done: () -> Void
    @State private var step: Int

    init(start: Int = 0, done: @escaping () -> Void) {
        self.done = done
        _step = State(initialValue: start)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Theme.night.ignoresSafeArea()
            Group {
                switch step {
                case 0: WelcomeStep { go(1) }
                case 1: ScreenTimeStep { go(2) }
                default: TourAppsStep(next: done)
                }
            }
            .padding(.horizontal, 28).padding(.top, 34).padding(.bottom, 16)
            .transition(.asymmetric(insertion: .opacity, removal: .opacity.combined(with: .offset(y: -6))))
            .id(step)

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule().fill(i <= step ? Theme.amber : Theme.line).frame(width: i == step ? 18 : 6, height: 6)
                }
            }
            .padding(.top, 10)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: step)
        }
    }

    private func go(_ s: Int) { withAnimation(.easeOut(duration: 0.3)) { step = s } }
}

private struct WelcomeStep: View {
    @EnvironmentObject var store: UserStore
    var next: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ring: CGFloat = 0
    @State private var star = false

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            ZStack {
                TwinkleSky(stars: 1, seed: 7, dust: 50, height: 1).frame(width: 320, height: 240).opacity(star ? 1 : 0)
                OrbitLogo(size: 110, progress: ring, starVisible: star)
            }
            .frame(height: 240)
            Label12("you're in").padding(.top, 10).rise(1)
            Headline("welcome to ", amber: "starlit", ", \(store.displayNameOrYou).", size: 34)
                .multilineTextAlignment(.center).rise(2)
            Text("your sky starts tonight. a quick setup, then we'll show you around.")
                .font(Theme.font(16)).foregroundColor(Theme.muted).multilineTextAlignment(.center).rise(3)
            Spacer()
            PrimaryButton(title: "let's go", action: next).rise(4)
        }
        .onAppear {
            Haptics.success()
            if reduceMotion { ring = 1; star = true; return }
            withAnimation(.easeInOut(duration: 1.1)) { ring = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                Haptics.star()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { star = true }
            }
        }
    }
}

private struct ScreenTimeStep: View {
    @EnvironmentObject var store: UserStore
    var next: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Spacer().frame(height: 50)
            Image(systemName: "hourglass")
                .font(.system(size: 28)).foregroundColor(Theme.amber)
                .frame(width: 64, height: 64).background(Circle().fill(Theme.card2))
                .padding(.bottom, 10).rise(0)
            Headline("let starlit ", amber: "rest", " your apps.").rise(1)
            Text("at bedtime, screen time keeps them closed until you wake up. it all stays on your phone.")
                .font(Theme.font(16)).foregroundColor(Theme.muted).rise(2)
            Spacer()
            PrimaryButton(title: "allow screen time") {
                Task {
                    try? await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                    // the shield's "i need it" reaches the app through a notification
                    _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                    store.syncLock()
                    next()
                }
            }
            .rise(3)
        }
    }
}

private struct TourAppsStep: View {
    @EnvironmentObject var store: UserStore
    var next: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Spacer().frame(height: 50)
            Headline("these rest at ", amber: UserStore.clock(store.wantMinutes), ".").rise(0)
            Text(store.screenTimeOK ? "pick the apps that keep you up. you can change them anytime."
                                    : "tap to change. you can edit this anytime.")
                .font(Theme.font(15)).foregroundColor(Theme.muted).padding(.bottom, 8).rise(1)
            ScrollView(showsIndicators: false) { RestingAppsPicker() }.rise(2)
            PrimaryButton(title: "continue", enabled: store.restingCount > 0, action: next).rise(3)
        }
    }
}

/// The walkthrough after setup. Tonight stops spotlight one card; the rest caption a whole screen.
enum TourStop: CaseIterable {
    case skyCard, appsCard, restNow, sky, resting, streak, restNights, you

    var tab: AppTab {
        switch self {
        case .sky: return .sky
        case .you: return .you
        default: return .tonight
        }
    }

    var moment: Moment? {
        switch self {
        case .resting: return .resting
        case .streak, .restNights: return .streak(justKept: false)
        default: return nil
        }
    }

    var spotlit: Bool { [.skyCard, .appsCard, .restNow, .restNights, .you].contains(self) }

    var title: String {
        switch self {
        case .skyCard: return "tonight"
        case .appsCard: return "resting apps"
        case .restNow: return "rest now"
        case .sky: return "your sky"
        case .resting: return "at bedtime"
        case .streak: return "your streak"
        case .restNights: return "rest nights"
        case .you: return "you"
        }
    }

    var text: String {
        switch self {
        case .skyCard: return "your countdown to bedtime. tap the card to open your sky."
        case .appsCard: return "these close at bedtime and open again when you wake up. tap to change them."
        case .restNow: return "heading to bed early? this rests your apps right away."
        case .sky: return "every night you keep lights a star. drag to look around, tap a star to see its night."
        case .resting: return "this is your phone at bedtime. open a resting app and it costs tonight's star."
        case .streak: return "nights kept in a row. every one lights a star in your sky."
        case .restNights: return "night out? use a rest night and your streak stays safe. you get one every week and can save up to 3."
        case .you: return "your bedtime, wake up and resting apps. change them anytime."
        }
    }

    var next: TourStop? {
        let all = Self.allCases
        let i = all.firstIndex(of: self)! + 1
        return i < all.count ? all[i] : nil
    }
}

/// With a `rect` (global coordinates): dims everything else and tap anywhere moves on.
/// Without one: the screen stays usable (e.g. drag the sky) and only the caption is tappable.
struct Spotlight: View {
    var stop: TourStop
    var rect: CGRect?
    var advance: () -> Void
    var skip: () -> Void

    private let gap: CGFloat = 18
    private let side: CGFloat = 20

    var body: some View {
        // outer reader only for the safe area: the inner one ignores it, so its insets read zero
        GeometryReader { outer in
            let safeBottom = outer.safeAreaInsets.bottom
            GeometryReader { geo in
                if let rect {
                    spotlit(rect, in: geo)
                } else {
                    ZStack(alignment: stop == .resting ? .center : .bottom) {
                        LinearGradient(colors: [.clear, Color.black.opacity(0.6)], startPoint: .center, endPoint: .bottom)
                            .allowsHitTesting(false)
                        caption
                            .padding(.horizontal, side)
                            // the sky tab still shows the tab bar; the full-screen moments don't
                            .padding(.bottom, stop == .resting ? 0 : stop == .sky ? safeBottom + 92 : max(8, safeBottom - 14))
                            .offset(y: stop == .resting ? 96 : 0)
                            .onTapGesture { Haptics.tap(); advance() }
                    }
                }
            }
            .ignoresSafeArea()
        }
    }

    private func spotlit(_ rect: CGRect, in geo: GeometryProxy) -> some View {
        let origin = geo.frame(in: .global).origin
        let r = rect.offsetBy(dx: -origin.x, dy: -origin.y).insetBy(dx: -6, dy: -6)
        let radius = stop == .skyCard ? 34 : stop == .restNow ? r.height / 2 : 26
        let above = r.midY > geo.size.height / 2
        let captionWidth = min(360, geo.size.width - side * 2)
        let captionMinX = (geo.size.width - captionWidth) / 2
        let pointerX = min(max(r.midX - 10, captionMinX + 26), captionMinX + captionWidth - 46)

        return ZStack(alignment: .topLeading) {
            Path { p in
                p.addRect(CGRect(origin: .zero, size: geo.size))
                p.addRoundedRect(in: r, cornerSize: CGSize(width: radius, height: radius))
            }
            .fill(Color.black.opacity(0.65), style: FillStyle(eoFill: true))

            RoundedRectangle(cornerRadius: radius)
                .stroke(Theme.amber.opacity(0.7), lineWidth: 1.5)
                .frame(width: r.width, height: r.height)
                .offset(x: r.minX, y: r.minY)

            Glass(shape: Pointer(down: above))
                .frame(width: 20, height: 9)
                .offset(x: pointerX, y: above ? r.minY - gap - 0.5 : r.maxY + gap - 8.5)

            caption
                .frame(width: geo.size.width,
                       height: max(0, above ? r.minY - gap : geo.size.height - r.maxY - gap),
                       alignment: above ? .bottom : .top)
                .offset(y: above ? 0 : r.maxY + gap)
        }
        .contentShape(Rectangle())
        .onTapGesture { Haptics.tap(); advance() }
    }

    private var caption: some View {
        let index = TourStop.allCases.firstIndex(of: stop) ?? 0
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(stop.title).font(Theme.font(14, .medium)).tracking(0.3).foregroundColor(Theme.amber)
                Spacer()
                Button("skip") { skip() }
                    .font(Theme.font(14)).foregroundColor(Theme.ivory.opacity(0.5))
            }
            Text(stop.text)
                .font(Theme.font(17)).foregroundColor(Theme.ivory).lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                HStack(spacing: 5) {
                    ForEach(TourStop.allCases.indices, id: \.self) { i in
                        Capsule().fill(i == index ? Theme.amber : Theme.ivory.opacity(0.2))
                            .frame(width: i == index ? 14 : 5, height: 5)
                    }
                }
                Spacer()
                Text("next")
                    .font(Theme.font(15, .medium)).foregroundColor(Theme.night)
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(Capsule().fill(Theme.ivory))
            }
            .padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: 360)
        .background(Glass(shape: RoundedRectangle(cornerRadius: 22)))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.ivory.opacity(0.1), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
        .contentShape(Rectangle())
    }
}

/// Frosted glass with the brand's warm tint (plain material reads cold gray on the dark UI).
private struct Glass<S: Shape>: View {
    var shape: S
    var body: some View {
        ZStack {
            shape.fill(.ultraThinMaterial)
            shape.fill(Theme.card.opacity(0.6))
        }
    }
}

/// The little triangle that points from a caption to its spotlight.
private struct Pointer: Shape {
    var down: Bool
    func path(in r: CGRect) -> Path {
        var p = Path()
        let tipY = down ? r.maxY : r.minY, baseY = down ? r.minY : r.maxY
        p.move(to: CGPoint(x: r.minX, y: baseY))
        p.addLine(to: CGPoint(x: r.midX, y: tipY))
        p.addLine(to: CGPoint(x: r.maxX, y: baseY))
        p.closeSubpath()
        return p
    }
}

/// The last page of the tour.
struct AllSetView: View {
    @EnvironmentObject var store: UserStore
    var done: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            OrbitLogo(size: 96).shadow(color: Theme.glow.opacity(0.45), radius: 24).rise(0)
            Headline("you're ", amber: "all set", ", \(store.displayNameOrYou).", size: 34)
                .multilineTextAlignment(.center).padding(.top, 18).rise(1)
            Text("keep tonight and your first star lights up in the morning.")
                .font(Theme.font(16)).foregroundColor(Theme.muted).multilineTextAlignment(.center).rise(2)
            Spacer()
            PrimaryButton(title: "see you at \(UserStore.clock(store.wantMinutes))") { Haptics.success(); done() }.rise(3)
        }
        .padding(.horizontal, 28).padding(.top, 34).padding(.bottom, 16)
        .background(ZStack { Theme.night; Embers() }.ignoresSafeArea())
    }
}
