import SwiftUI

/// The starlit orbit logo: a ring with a gap at -45°, and the amber star sitting on the ring in the gap.
struct OrbitLogo: View {
    var size: CGFloat = 64
    var ringColor: Color = Theme.ivory
    var progress: CGFloat = 1      // ring draw-in 0...1
    var starVisible: Bool = true

    var body: some View {
        ZStack {
            OrbitRing()
                .trim(from: 0, to: progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: size * 0.085, lineCap: .butt))
            if starVisible {
                Circle()
                    .fill(Theme.amber)
                    .frame(width: size * 0.26, height: size * 0.26)
                    .shadow(color: Theme.glow.opacity(0.7), radius: size * 0.12)
                    .offset(x: size * 0.42 * cos(-.pi / 4), y: size * 0.42 * sin(-.pi / 4))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: size, height: size)
    }
}

struct OrbitRing: Shape {
    func path(in rect: CGRect) -> Path {
        let r = min(rect.width, rect.height) * 0.42
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let star = -45.0, gap = 22.0
        var p = Path()
        p.addArc(center: c, radius: r,
                 startAngle: .degrees(star + gap),
                 endAngle: .degrees(star - gap + 360),
                 clockwise: false)
        return p
    }
}
