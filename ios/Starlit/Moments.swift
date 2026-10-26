import SwiftUI

// Full-screen moments. On a real phone, the shield is Apple's ShieldConfiguration extension
// (it can only show text, an icon and two buttons), so ShieldView here is the in-app version of it.

private func restingApps(_ store: UserStore) -> [String] {
    store.keepsUp.isEmpty ? ["tiktok", "instagram", "youtube"] : store.keepsUp.sorted()
}

/// "rest now": clock ring with a star travelling round it, and the apps that are resting.
struct RestingView: View {
    @EnvironmentObject var store: UserStore
    var openApp: (String) -> Void
    var close: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { tl in
            let c = Calendar.current.dateComponents([.hour, .minute], from: tl.date)
            let now = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            let bed = store.wantMinutes % 1440
            let len = max(60, ((store.wakeMinutes - bed) + 1440) % 1440)
            let elapsed = (now - bed + 1440) % 1440
            let p = min(0.98, max(0.02, Double(elapsed) / Double(len)))
            let left = max(0, len - elapsed)
            content(now: now, progress: p, left: left)
        }
        .background(TwinkleSky(stars: 7, seed: 21, dust: 60, height: 0.25).background(Theme.night).ignoresSafeArea())
    }

    private func content(now: Int, progress p: Double, left: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                (Text("NIGHT ") + Text("\(store.nightsKept + 1)").foregroundColor(Theme.amber)).font(Theme.font(12)).tracking(1).foregroundColor(Theme.muted)
                Spacer()
                (Text("● ").foregroundColor(Theme.amber) + Text("RESTING")).font(Theme.font(12)).tracking(1).foregroundColor(Theme.muted)
            }
            ZStack {
                Circle().stroke(Theme.ivory.opacity(0.1), lineWidth: 5)
                Circle().trim(from: 0, to: CGFloat(p)).stroke(Theme.ivory, lineWidth: 5).rotationEffect(.degrees(-90))
                GeometryReader { g in
                    let r = Double(g.size.width) / 2, a = (-90 + 360 * p) * Double.pi / 180
                    Circle().fill(Theme.amber).frame(width: 18, height: 18)
                        .shadow(color: Theme.glow.opacity(0.8), radius: 12)
                        .position(x: CGFloat(r + r * cos(a)), y: CGFloat(r + r * sin(a)))
                }
                VStack(spacing: 4) {
                    Text(UserStore.clock(now)).font(Theme.font(64, .light)).tracking(-3).monospacedDigit().foregroundColor(Theme.ivory)
                    Text("\(left / 60)h \(String(format: "%02d", left % 60))m until \(UserStore.clock(store.wakeMinutes))")
                        .font(Theme.font(15)).foregroundColor(Theme.muted)
                }
            }
            .frame(width: 236, height: 236)
            .frame(maxWidth: .infinity)
            .padding(.top, 30)
            Spacer()
            Label12("resting till morning · tap one")
            FlowLayout(spacing: 8) {
                ForEach(restingApps(store), id: \.self) { a in
                    Button { Haptics.warning(); openApp(a) } label: {
                        Text(a).font(Theme.font(15)).foregroundColor(Theme.muted)
                            .padding(.horizontal, 16).padding(.vertical, 10).card(14)
                    }
                    .buttonStyle(PressStyle())
                }
            }
            Button("back to app", action: close).font(Theme.font(15)).foregroundColor(Theme.muted).frame(maxWidth: .infinity).padding(10)
        }
        .padding(.horizontal, 26).padding(.top, 14).padding(.bottom, 10)
    }
}

/// Opening a resting app.
struct ShieldView: View {
    @EnvironmentObject var store: UserStore
    var app: String
    var backToSleep: () -> Void
    var unlocked: () -> Void
    @State private var shake = 0
    @State private var asking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Spacer()
            (Text("NIGHT ") + Text("\(store.nightsKept + 1)").foregroundColor(Theme.amber) + Text(" · \(app.uppercased())"))
                .font(Theme.font(12)).tracking(1).foregroundColor(Theme.muted)
            Headline("your phone is ", amber: "resting", " until \(UserStore.clock(store.wakeMinutes)).", size: 36)
            Text("tonight's star is waiting for you, \(store.displayNameOrYou).").font(Theme.font(15)).foregroundColor(Theme.muted)
            Spacer()
            PrimaryButton(title: "back to sleep", action: backToSleep)
            Button { Haptics.warning(); asking = true } label: {
                Text("i need it (costs tonight's star)").font(Theme.font(15)).foregroundColor(Theme.muted).frame(maxWidth: .infinity).padding(10)
            }
        }
        .modifier(Shake(amount: CGFloat(shake)))
        .padding(.horizontal, 26).padding(.vertical, 14)
        .background(TwinkleSky(stars: store.nightsKept, seed: 31, dust: 70, height: 0.3).background(Theme.night).ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture { Haptics.warning(); withAnimation(.linear(duration: 0.45)) { shake += 1 } }
        .sheet(isPresented: $asking) {
            VStack(alignment: .leading, spacing: 12) {
                Text("unlock for 15 minutes?").font(Theme.font(24)).foregroundColor(Theme.ivory).padding(.top, 26)
                Text("tonight's star stays dark. your sky keeps the rest.").font(Theme.font(15)).foregroundColor(Theme.muted)
                Spacer()
                PrimaryButton(title: "keep my star") { asking = false; Haptics.success() }
                Button("unlock anyway") { asking = false; unlocked() }
                    .font(Theme.font(15)).foregroundColor(Theme.muted).frame(maxWidth: .infinity).padding(10)
            }
            .padding(.horizontal, 26)
            .presentationDetents([.height(300)])
            .presentationBackground(Color(red: 28/255, green: 25/255, blue: 21/255))
        }
    }
}

struct Shake: GeometryEffect {
    var amount: CGFloat
    var animatableData: CGFloat { get { amount } set { amount = newValue } }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(amount * .pi * 4) * (1 - amount.truncatingRemainder(dividingBy: 1)), y: 0))
    }
}

struct GoodnightView: View {
    @EnvironmentObject var store: UserStore
    @State private var on = false
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("goodnight, \(store.displayNameOrYou).").font(Theme.font(16)).foregroundColor(Theme.muted)
                .opacity(on ? 1 : 0).blur(radius: on ? 0 : 6)
        }
        .onAppear { withAnimation(.easeOut(duration: 1.2)) { on = true } }
    }
}

struct MorningView: View {
    @EnvironmentObject var store: UserStore
    var seeSky: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Spacer()
            Label12("good morning · \(UserStore.clock(store.wakeMinutes))").rise(0)
            Headline("you kept your ", amber: "night", ", \(store.displayNameOrYou).", size: 36).rise(1)
            HStack(spacing: 10) {
                stat("7h 42m", "phone-free")
                stat("\(store.nightsKept + 1)", "nights kept")
            }
            .padding(.top, 8).rise(2)
            Spacer()
            PrimaryButton(title: "see your sky", action: seeSky).rise(3)
        }
        .padding(.horizontal, 26).padding(.vertical, 14)
        .background(
            ZStack {
                LinearGradient(colors: [Color(red: 29/255, green: 24/255, blue: 20/255), Color(red: 42/255, green: 33/255, blue: 25/255), Color(red: 58/255, green: 44/255, blue: 30/255)],
                               startPoint: .top, endPoint: .bottom)
                TwinkleSky(stars: store.nightsKept + 1, seed: 51, dust: 40, height: 0.3, amberLast: true)
            }
            .ignoresSafeArea()
        )
    }

    private func stat(_ v: String, _ k: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(v).font(Theme.font(26)).foregroundColor(Theme.ivory)
            Text(k).font(Theme.font(12)).foregroundColor(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(14).card(20)
    }
}

// MARK: - streak

/// Big glowing logo, amber count, the week with kept days joined in a pill, and what's next.
struct StreakView: View {
    @EnvironmentObject var store: UserStore
    var justKept: Bool
    var close: () -> Void
    @State private var shown = 0
    @State private var popNewest = false
    @State private var floatUp = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .medium)).foregroundColor(Theme.muted)
                        .frame(width: 36, height: 36).background(Circle().fill(Theme.ivory.opacity(0.08)))
                }
            }
            Spacer()
            OrbitLogo(size: 118)
                .shadow(color: Theme.glow.opacity(0.45), radius: 24)
                .offset(y: floatUp ? -6 : 0)
            Text("\(shown)")
                .font(Theme.font(120)).tracking(-7).monospacedDigit()
                .foregroundColor(Theme.amber)
                .shadow(color: Theme.glow.opacity(0.45), radius: 30)
                .contentTransition(.numericText(value: Double(shown)))
                .padding(.top, 10)
            Text("nights in a row").font(Theme.font(26)).tracking(-0.8).foregroundColor(Theme.ivory)
            weekCard.padding(.top, 26)
            Spacer()
            PrimaryButton(title: "keep it going", action: close)
        }
        .padding(.horizontal, 26).padding(.top, 14).padding(.bottom, 10)
        .background(
            ZStack {
                Theme.night
                Embers()
            }
            .ignoresSafeArea()
        )
        .onAppear {
            shown = justKept ? max(0, store.streak - 1) : store.streak
            withAnimation(.easeInOut(duration: 4).repeatForever()) { floatUp = true }
            guard justKept else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                Haptics.success()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { shown = store.streak; popNewest = true }
            }
        }
    }

    private var weekCard: some View {
        let today = UserStore.weekdayIndex
        let thru = justKept ? today : today - 1
        let monday = Calendar.current.date(byAdding: .day, value: -today, to: Date()) ?? Date()
        let next = [7, 14, 30, 60, 100].first { $0 > store.streak } ?? store.streak + 30
        let left = next - store.streak
        return VStack(spacing: 14) {
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    dayCell(i, today: today, thru: thru, monday: monday)
                }
            }
            Rectangle().fill(Theme.line).frame(height: 1)
            Text((justKept ? "night \(store.nightsKept) is in your sky, \(store.displayNameOrYou). " : "you're glowing, \(store.displayNameOrYou). ")
                 + "\(left) more \(left == 1 ? "night" : "nights") and your sky unlocks a new color ✦")
                .font(Theme.font(15)).foregroundColor(Theme.ivory).multilineTextAlignment(.center).padding(.horizontal, 8)
        }
        .padding(.horizontal, 12).padding(.top, 16).padding(.bottom, 18)
        .background(RoundedRectangle(cornerRadius: 24).fill(Theme.card.opacity(0.85)))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.line, lineWidth: 1))
    }

    @ViewBuilder private func dayCell(_ i: Int, today: Int, thru: Int, monday: Date) -> some View {
        let st = store.dayState(i, today: today, keptThrough: thru)
        let kept = st == .kept
        let runL = kept && store.dayState(i - 1, today: today, keptThrough: thru) != .kept
        let runR = kept && store.dayState(i + 1, today: today, keptThrough: thru) != .kept
        let newest = justKept && i == thru
        let date = Calendar.current.component(.day, from: Calendar.current.date(byAdding: .day, value: i, to: monday) ?? monday)
        VStack(spacing: 10) {
            Text(["m", "t", "w", "t", "f", "s", "s"][i]).font(Theme.font(12)).foregroundColor(Theme.muted)
            ZStack {
                if kept {
                    UnevenRoundedRectangle(topLeadingRadius: runL ? 99 : 0, bottomLeadingRadius: runL ? 99 : 0,
                                           bottomTrailingRadius: runR ? 99 : 0, topTrailingRadius: runR ? 99 : 0)
                        .fill(Theme.amber.opacity(0.12))
                        .padding(.leading, runL ? 4 : 0).padding(.trailing, runR ? 4 : 0)
                }
                Group {
                    if newest {
                        Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundColor(Theme.night)
                            .frame(width: 30, height: 30).background(Circle().fill(Theme.amber))
                            .shadow(color: Theme.glow.opacity(0.6), radius: 7)
                            .scaleEffect(popNewest ? 1 : 0.01)
                    } else if kept {
                        Image(systemName: "checkmark").font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.amber)
                    } else if st == .missed {
                        Text("\(date)").strikethrough().foregroundColor(Theme.muted.opacity(0.6))
                    } else {
                        Text("\(date)").foregroundColor(Theme.ivory).frame(width: 30, height: 30).background(Circle().fill(Theme.card2))
                    }
                }
                .font(Theme.font(13))
            }
            .frame(height: 36)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Amber sparks drifting up behind the streak logo.
struct Embers: View {
    private let parts: [(x: Double, ph: Double, sp: Double, sz: Double)] = {
        var r = Seeded(9)
        return (0..<26).map { _ -> (x: Double, ph: Double, sp: Double, sz: Double) in ((r.next() - 0.5) * 170, r.next(), 0.25 + r.next() * 0.35, 1 + r.next() * 2.4) }
    }()
    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                let cx = Double(size.width) / 2, cy = Double(size.height) * 0.33
                ctx.glowDot(CGPoint(x: cx, y: cy), r: 0, color: .clear, glowR: 190, glowA: 0.22)
                for p in parts {
                    let k = (p.ph + t * p.sp * 0.3).truncatingRemainder(dividingBy: 1)
                    let y = cy + 70 - k * 230
                    let x = cx + p.x * (1 - k * 0.3) + sin(t + p.ph * 9) * 6
                    ctx.glowDot(CGPoint(x: x, y: y), r: CGFloat(p.sz * 0.8), color: Theme.amber, alpha: sin(k * .pi) * 0.8)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
