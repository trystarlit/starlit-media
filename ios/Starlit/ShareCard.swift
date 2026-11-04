import SwiftUI
import UIKit

/// The streak as a card on a soft night background, 4:5 so Messages shows it whole (and it fits an IG post).
struct ShareCard: View {
    var streak: Int
    var nights: Int
    var bedtime: String

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 18/255, green: 15/255, blue: 12/255), Color(red: 30/255, green: 24/255, blue: 18/255)],
                           startPoint: .top, endPoint: .bottom)
            Canvas { ctx, size in
                var r = Seeded(91)
                for _ in 0..<70 {
                    let p = CGPoint(x: r.next() * size.width, y: r.next() * size.height)
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - 0.7, y: p.y - 0.7, width: 1.4, height: 1.4)), with: .color(Theme.ivory.opacity(0.18)))
                }
            }
            card.padding(22)
        }
        .frame(width: 360, height: 450)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                OrbitLogo(size: 22)
                Text("starlit").font(Theme.font(17, .medium)).foregroundColor(Theme.ivory)
                Spacer()
                Text("night \(nights)").font(Theme.font(13)).foregroundColor(Theme.muted)
            }
            // their sky: one star per kept night, the newest in amber
            Canvas { ctx, size in
                var d = Seeded(13)
                for _ in 0..<55 {
                    let p = CGPoint(x: d.next() * size.width, y: d.next() * size.height)
                    let a = 0.12 + d.next() * 0.22
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - 0.8, y: p.y - 0.8, width: 1.6, height: 1.6)), with: .color(Theme.ivory.opacity(a)))
                }
                var r = Seeded(77)
                let n = min(max(nights, 1), 80)
                for i in 0..<n {
                    let p = CGPoint(x: 0.06 * size.width + r.next() * size.width * 0.88, y: 0.1 * size.height + r.next() * size.height * 0.8)
                    let last = i == n - 1
                    ctx.glowDot(p, r: last ? 3 : 1.8, color: last ? Theme.amber : Theme.ivory, alpha: 0.95,
                                glowR: last ? 18 : 7, glowA: last ? 0.6 : 0.22)
                }
            }
            .frame(height: 96)
            .padding(.vertical, 10)
            Text("\(streak)")
                .font(Theme.font(92, .light)).monospacedDigit().foregroundColor(Theme.amber)
                .shadow(color: Theme.glow.opacity(0.45), radius: 24)
            Text(streak == 1 ? "night in a row" : "nights in a row").font(Theme.font(24)).foregroundColor(Theme.ivory)
            Text("phone down at \(bedtime)").font(Theme.font(15)).foregroundColor(Theme.muted).padding(.top, 6)
            Rectangle().fill(Theme.line).frame(height: 1).padding(.vertical, 14)
            HStack {
                Text("get your nights back").font(Theme.font(13)).foregroundColor(Theme.muted)
                Spacer()
                Text("trystarlit.netlify.app").font(Theme.font(13, .medium)).foregroundColor(Theme.amber)
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(LinearGradient(colors: [Color(red: 26/255, green: 22/255, blue: 18/255), Color(red: 18/255, green: 15/255, blue: 12/255)],
                                     startPoint: .top, endPoint: .bottom))
        )
        .overlay(RoundedRectangle(cornerRadius: 32).stroke(Theme.ivory.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 30, y: 16)
    }
}

/// "share" button: the card image plus a message with the link, through the iPhone share sheet.
struct ShareStreakButton: View {
    @EnvironmentObject var store: UserStore
    var streak: Int
    @State private var items: [Any]?

    var body: some View {
        Button {
            Haptics.tap()
            Analytics.track("share_streak", ["streak": streak])
            items = shareItems()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up").font(.system(size: 15, weight: .medium))
                Text("share my streak").font(Theme.font(16))
            }
            .foregroundColor(Theme.ivory)
            .frame(maxWidth: .infinity).padding(.vertical, 15)
            .background(Capsule().fill(Theme.ivory.opacity(0.08)))
            .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
        }
        .buttonStyle(PressStyle())
        .sheet(isPresented: Binding(get: { items != nil }, set: { if !$0 { items = nil } })) {
            ShareSheet(items: items ?? []).presentationDetents([.medium, .large])
        }
    }

    @MainActor private func shareItems() -> [Any] {
        let bedtime = UserStore.clock(store.wantMinutes) + UserStore.ampm(store.wantMinutes)
        let renderer = ImageRenderer(content: ShareCard(streak: streak, nights: max(store.nightsKept, streak), bedtime: bedtime))
        renderer.scale = 3   // 1080 x 1350
        let message = (streak == 1 ? "night 1 with my phone down at bedtime 🌙"
                                   : "\(streak) nights in a row with my phone down at bedtime 🌙")
            + " building my streak on starlit: \(Links.share.absoluteString)"
        var items: [Any] = []
        if let image = renderer.uiImage { items.append(image) }
        items.append(message)
        return items
    }
}

/// The system share sheet (image + text + link together, which ShareLink can't do).
struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
