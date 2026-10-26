import SwiftUI

/// A sky of kept nights. Stars are placed with a seeded generator so the same sky always looks the same.
struct SkyView: View {
    var nights: Int
    var tonightLit: Bool = false
    var showTonightSlot: Bool = true
    var seed: UInt64 = 9

    @State private var pulse = false

    var body: some View {
        GeometryReader { geo in
            let pts = SkyView.points(count: nights + 1, in: geo.size, seed: seed)
            ZStack {
                ForEach(0..<nights, id: \.self) { i in
                    let big = i % 3 == 2
                    Circle()
                        .fill(Theme.ivory.opacity(0.6 + Double((i * 37) % 40) / 100))
                        .frame(width: big ? 6 : 3.5, height: big ? 6 : 3.5)
                        .shadow(color: Theme.glow.opacity(0.35), radius: big ? 6 : 3)
                        .position(pts[i])
                }
                if showTonightSlot, let p = pts.last {
                    if tonightLit {
                        Circle()
                            .fill(Theme.amber)
                            .frame(width: 12, height: 12)
                            .shadow(color: Theme.glow.opacity(0.9), radius: 14)
                            .position(p)
                            .transition(.scale(scale: 0.1).combined(with: .opacity))
                    } else {
                        Circle()
                            .strokeBorder(Theme.amber.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                            .frame(width: 16, height: 16)
                            .opacity(pulse ? 0.35 : 1)
                            .position(p)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    static func points(count: Int, in size: CGSize, seed: UInt64) -> [CGPoint] {
        var s = seed &* 2654435761 &+ 1
        func rnd() -> CGFloat { s = s &* 6364136223846793005 &+ 1442695040888963407; return CGFloat((s >> 33) % 10_000) / 10_000 }
        var out: [CGPoint] = []
        let pad: CGFloat = 18
        for _ in 0..<count {
            var best = CGPoint.zero
            for _ in 0..<40 {
                let p = CGPoint(x: pad + rnd() * (size.width - 2 * pad), y: pad + rnd() * (size.height - 2 * pad))
                best = p
                if out.allSatisfy({ hypot($0.x - p.x, $0.y - p.y) > 26 }) { break }
            }
            out.append(best)
        }
        return out
    }
}
