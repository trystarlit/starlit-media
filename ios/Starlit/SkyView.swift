import SwiftUI

// MARK: - helpers

/// Deterministic random numbers so the same sky always looks the same.
struct Seeded {
    private var s: UInt64
    init(_ seed: UInt64) { s = seed &* 2654435761 &+ 1 }
    mutating func next() -> Double {
        s = s &* 6364136223846793005 &+ 1442695040888963407
        return Double((s >> 33) % 100_000) / 100_000
    }
}

extension GraphicsContext {
    /// A dot with an optional soft amber glow behind it.
    func glowDot(_ p: CGPoint, r: CGFloat, color: Color, alpha: Double = 1, glowR: CGFloat = 0, glowA: Double = 0) {
        if glowR > 0 && glowA > 0 {
            fill(Path(ellipseIn: CGRect(x: p.x - glowR, y: p.y - glowR, width: glowR * 2, height: glowR * 2)),
                 with: .radialGradient(Gradient(colors: [Theme.glow.opacity(glowA), Theme.glow.opacity(0)]),
                                       center: p, startRadius: 0, endRadius: glowR))
        }
        guard r > 0 else { return }
        fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(color.opacity(alpha)))
    }
}

struct SkyStar { var x: Double; var y: Double; var r: Double; var phase: Double; var speed: Double }

// MARK: - flat twinkling sky (splash, wow, home card, resting, shield, morning)

struct TwinkleSky: View {
    private let stars: [SkyStar]
    private let dust: [SkyStar]
    var amberLast: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(stars n: Int, seed: UInt64, dust d: Int = 70, height: Double = 0.62, amberLast: Bool = false) {
        var r = Seeded(seed)
        var st: [SkyStar] = []
        for i in 0..<max(0, n) {
            var p = SkyStar(x: 0, y: 0, r: i % 3 == 2 ? 2.6 : 1.8, phase: 0, speed: 1)
            for _ in 0..<50 {
                p.x = 0.08 + r.next() * 0.84; p.y = 0.1 + r.next() * height
                if st.allSatisfy({ hypot($0.x - p.x, ($0.y - p.y) * 1.6) > 0.07 }) { break }
            }
            p.phase = r.next() * 6.28
            st.append(p)
        }
        var r2 = Seeded(seed + 1)
        dust = (0..<d).map { _ in SkyStar(x: r2.next(), y: r2.next(), r: 0.4 + r2.next() * 1.1, phase: r2.next() * 6.28, speed: 0.4 + r2.next()) }
        stars = st
        self.amberLast = amberLast
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: reduceMotion)) { tl in   // Reduce Motion: still sky, no twinkle
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                let W = Double(size.width), H = Double(size.height)
                for o in dust {
                    ctx.glowDot(CGPoint(x: o.x * W, y: o.y * H), r: CGFloat(o.r), color: Theme.ivory,
                                alpha: 0.12 + 0.1 * sin(t * o.speed + o.phase))
                }
                for (i, p) in stars.enumerated() {
                    let tw = 0.75 + 0.25 * sin(t * 1.3 + p.phase)
                    let last = amberLast && i == stars.count - 1
                    let r = p.r * (last ? 1.6 : 1)
                    ctx.glowDot(CGPoint(x: p.x * W, y: p.y * H), r: CGFloat(r),
                                color: last ? Theme.amber : Theme.ivory, alpha: tw,
                                glowR: CGFloat(p.r * (last ? 10 : 5)), glowA: last ? 0.5 : 0.18)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 3D sky (sky tab)

/// Camera physics for the 3D sky. Horizontal drag is free; vertical drag is stiff and springs back.
/// After you let go it coasts, waits 2s, then eases back into a slow spin.
final class SkyCamera {
    static let pitch0 = -0.15, auto = 0.0012
    var yaw = 0.6, pitch = SkyCamera.pitch0, vy = SkyCamera.auto
    var spin = SkyCamera.auto        // 0 with Reduce Motion: the sky only moves when you drag it
    var dragging = false
    var released = Date.distantPast
    var lastTick: Date?
    var lastLoc: CGPoint = .zero
    var born: Date?                  // when tonight's new star starts lighting up

    func step(_ now: Date) {
        let dt = min(0.05, now.timeIntervalSince(lastTick ?? now)); lastTick = now
        let k = dt * 60
        guard !dragging else { return }
        yaw += vy * k
        vy *= pow(0.94, k)
        let idle = now.timeIntervalSince(released)
        if idle > 2 { vy += (spin - vy) * min(1, (idle - 2) / 1.5) * min(1, 0.06 * k) }
        pitch += (SkyCamera.pitch0 - pitch) * min(1, 0.08 * k)
    }

    func drag(dx: CGFloat, dy: CGFloat) {
        yaw += Double(dx) * 0.0035
        vy = Double(dx) * 0.0035
        let off = pitch - SkyCamera.pitch0
        pitch += Double(dy) * 0.0015 * max(0.1, 1 - abs(off) / 0.45)
    }

    /// Returns screen point, depth (-1 back ... 1 front), perspective scale.
    func project(_ p: SIMD3<Double>, _ size: CGSize) -> (CGPoint, Double, Double) {
        let cy = cos(yaw), sy = sin(yaw), cp = cos(pitch), sp = sin(pitch)
        let x1 = p.x * cy + p.z * sy, z1 = -p.x * sy + p.z * cy
        let y1 = p.y * cp - z1 * sp, z2 = p.y * sp + z1 * cp
        let d = 2.8, k = d / (d - z2), R = Double(min(size.width, size.height)) * 0.42
        let W = Double(size.width), H = Double(size.height)
        return (CGPoint(x: W / 2 + x1 * R * k, y: H * 0.52 + y1 * R * k), z2, k)
    }
}

struct Sky3DView: View {
    var nights: Int
    var newStar: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var cam = SkyCamera()
    @State private var sel: Int?
    @State private var start: CGPoint?
    private let stars: [(p: SIMD3<Double>, r: Double)]
    private let dust: [(p: SIMD3<Double>, r: Double)]

    init(nights: Int, newStar: Bool = false) {
        self.nights = nights; self.newStar = newStar
        var r = Seeded(41)
        func pt() -> SIMD3<Double> {
            let u = r.next() * 2 - 1, a = r.next() * 6.283, q = (1 - u * u).squareRoot()
            return SIMD3(q * cos(a), u * 0.8, q * sin(a))
        }
        var st: [(p: SIMD3<Double>, r: Double)] = []
        for i in 0..<max(0, nights) { let p = pt(); st.append((p, i % 3 == 2 ? 3.4 : 2.2 + r.next())) }
        var ds: [(p: SIMD3<Double>, r: Double)] = []
        for _ in 0..<180 { let p = pt(); ds.append((p * (1.6 + r.next() * 0.6), 0.5 + r.next() * 0.7)) }
        stars = st; dust = ds
    }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { tl in
                Canvas { ctx, size in draw(ctx, size, tl.date) }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if !cam.dragging { cam.dragging = true; cam.vy = 0; cam.lastLoc = v.startLocation; start = v.startLocation }
                        cam.drag(dx: v.location.x - cam.lastLoc.x, dy: v.location.y - cam.lastLoc.y)
                        cam.lastLoc = v.location
                    }
                    .onEnded { v in
                        cam.dragging = false; cam.released = Date()
                        if hypot(v.translation.width, v.translation.height) < 8 { pick(v.location, geo.size) }
                    }
            )
        }
        .onAppear {
            if reduceMotion { cam.spin = 0; cam.vy = 0 }
            guard newStar, nights > 0 else { return }
            let p = stars[nights - 1].p
            cam.yaw = atan2(-p.x, p.z); cam.vy = 0                      // face tonight's star
            cam.born = Date().addingTimeInterval(0.5)
            cam.released = Date().addingTimeInterval(2.5)                // hold still while it lights
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { Haptics.star() }
        }
    }

    private func pick(_ loc: CGPoint, _ size: CGSize) {
        var best: Int?, bd: CGFloat = 34
        for (i, s) in stars.enumerated() {
            let (pt, z, _) = cam.project(s.p, size)
            let d = hypot(pt.x - loc.x, pt.y - loc.y)
            if z > -0.2 && d < bd { bd = d; best = i }
        }
        sel = best
        if best != nil { Haptics.select() }
    }

    private func tip(for i: Int) -> String {
        let d = Calendar.current.date(byAdding: .day, value: -(nights - 1 - i), to: Date()) ?? Date()
        let f = DateFormatter(); f.dateFormat = "MMM d"
        // date + night number only; per-night phone-free time comes later from real Screen Time data
        return "\(f.string(from: d).lowercased()) · night \(i + 1)"
    }

    private func draw(_ ctx: GraphicsContext, _ size: CGSize, _ now: Date) {
        cam.step(now)
        for d in dust {
            let (pt, z, k) = cam.project(d.p, size)
            ctx.glowDot(pt, r: d.r * k, color: Theme.ivory, alpha: 0.06 + 0.2 * (z + 2) / 4)
        }
        let P = stars.map { cam.project($0.p, size) }
        let order = P.indices.sorted { P[$0].1 < P[$1].1 }
        for i in order {
            let (pt, z, k) = P[i], s = stars[i]
            let a = 0.25 + 0.75 * (z + 1) / 2
            if let born = cam.born, i == nights - 1 {                     // tonight's star lights up
                let t = now.timeIntervalSince(born)
                if t < 0 { continue }
                let g = min(1, t / 0.7), e = 1 - pow(1 - g, 3)
                let bloom = t < 1.4 ? sin(min(1, t / 1.4) * .pi) : 0
                for q in 0..<2 {
                    let rt = t - Double(q) * 0.35
                    if rt > 0 && rt < 1.6 {
                        let rr = CGFloat(8 + rt * 70)
                        ctx.stroke(Path(ellipseIn: CGRect(x: pt.x - rr, y: pt.y - rr, width: rr * 2, height: rr * 2)),
                                   with: .color(Theme.amber.opacity(0.55 * (1 - rt / 1.6))), lineWidth: 1.5)
                    }
                }
                if t < 0.9 {
                    var rays = Path()
                    for q in 0..<4 {
                        let an = Double(q) * .pi / 2 + .pi / 4, L = 14 + 40 * e
                        let end = CGPoint(x: Double(pt.x) + cos(an) * L, y: Double(pt.y) + sin(an) * L)
                        rays.move(to: pt); rays.addLine(to: end)
                    }
                    ctx.stroke(rays, with: .color(Theme.amber.opacity(0.5 * (1 - t / 0.9))), lineWidth: 1)
                }
                ctx.glowDot(pt, r: s.r * k * 1.5 * e * (1 + 0.6 * bloom), color: Theme.amber, alpha: e,
                            glowR: s.r * k * (10 + 22 * bloom) * e, glowA: 0.5 + 0.4 * bloom)
                continue
            }
            let hi = i == nights - 1 || i == sel
            ctx.glowDot(pt, r: s.r * k * (hi ? 1.5 : 1), color: hi ? Theme.amber : Theme.ivory, alpha: a,
                        glowR: s.r * k * (hi ? 10 : 6), glowA: (hi ? 0.5 : 0.2) * a)
        }
        if let i = sel, i < P.count, P[i].1 > -0.3 {
            let label = ctx.resolve(Text(tip(for: i)).font(Theme.font(13)).foregroundColor(Theme.ivory))
            let m = label.measure(in: CGSize(width: 320, height: 40))
            let c = CGPoint(x: P[i].0.x, y: P[i].0.y - 30)
            let box = CGRect(x: c.x - m.width / 2 - 14, y: c.y - m.height / 2 - 8, width: m.width + 28, height: m.height + 16)
            ctx.fill(Capsule().path(in: box), with: .color(Theme.card2))
            ctx.stroke(Capsule().path(in: box), with: .color(Theme.line), lineWidth: 1)
            ctx.draw(label, at: c)
        }
    }
}
