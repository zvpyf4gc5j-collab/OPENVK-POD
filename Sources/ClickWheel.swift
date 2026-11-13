import SwiftUI

struct ClickWheel: View {
    @EnvironmentObject var pod: Pod
    let u: CGFloat
    @State private var last: Double? = nil
    @State private var acc = 0.0
    @State private var moved = 0.0
    @State private var t0 = Date()

    var body: some View {
        let w = wheelPresets[pod.wheelIdx]
        GeometryReader { g in
            let c = CGPoint(x: g.size.width / 2, y: g.size.height / 2)
            ZStack {
                Circle().fill(w.1).shadow(color: .black.opacity(0.25), radius: 3 * u, y: u)
                Text("MENU").font(.system(size: 4.6 * u, weight: .bold)).foregroundColor(w.2).position(x: c.x, y: 7.2 * u)
                Image(systemName: "backward.end.fill").foregroundColor(w.2).position(x: 9 * u, y: c.y)
                Image(systemName: "forward.end.fill").foregroundColor(w.2).position(x: 61 * u, y: c.y)
                Image(systemName: "playpause.fill").foregroundColor(w.2).position(x: c.x, y: 65.6 * u)
                Circle().fill(w.1)
                    .overlay(Circle().fill(LinearGradient(colors: [.black.opacity(0.28), .black.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                    .frame(width: 24.4 * u, height: 24.4 * u)
            }
            .font(.system(size: 4.4 * u, weight: .bold))
            .contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in
                    let a = atan2(v.location.y - c.y, v.location.x - c.x) * 180 / .pi
                    guard let l = last else { last = a; acc = 0; moved = 0; t0 = Date(); return }
                    var d = a - l
                    if d > 180 { d -= 360 }
                    if d < -180 { d += 360 }
                    last = a
                    moved += abs(d)
                    acc += d
                    while acc >= 28 { acc -= 28; pod.haptic(); pod.step(1) }
                    while acc <= -28 { acc += 28; pod.haptic(); pod.step(-1) }
                }
                .onEnded { v in
                    defer { last = nil }
                    let dt = Date().timeIntervalSince(t0)
                    if moved > 10 || dt > 0.5 { return }
                    let dx = v.location.x - c.x, dy = v.location.y - c.y
                    pod.haptic()
                    if hypot(dx, dy) < g.size.width * 0.17 { pod.select() }
                    else if abs(dy) > abs(dx) { if dy < 0 { pod.back() } else { pod.player.toggle() } }
                    else if dx > 0 { pod.player.next() } else { pod.player.prev() }
                })
        }
    }
}
