import SwiftUI

struct DesktopControlsView: View {
    @ObservedObject var networkService: NetworkService
    let screenSize: CGSize
    @AppStorage("mouseSensitivity") private var sensitivity: Double = 1.0

    @State private var lastTap = Date.distantPast
    @State private var touchCount = 0
    @State private var flash = false
    @State private var isDown = false
    @State private var accumulated = CGSize.zero
    @State private var lastDrag = CGSize.zero
    @State private var scrollMode = false

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { v in
                    if v.numberOfTouchPoints > 1 {
                        if !scrollMode { scrollMode = true; accumulated = .zero }
                        let d = CGSize(width: v.translation.width - lastDrag.width,
                                       height: v.translation.height - lastDrag.height)
                        networkService.sendScroll(dy: d.height * 0.5)
                    } else if !scrollMode {
                        let accel = 0.6 + sensitivity * 0.8
                        let dx = (v.translation.width - lastDrag.width) * accel
                        let dy = (v.translation.height - lastDrag.height) * accel
                        networkService.sendRelativeMove(dx: dx, dy: dy)
                    }
                    lastDrag = v.translation
                    if !isDown { isDown = true; tapCheck() }
                }
                .onEnded { _ in
                    isDown = false; scrollMode = false
                    accumulated = .zero; lastDrag = .zero
                    let n = Date()
                    if n.timeIntervalSince(lastTap) < 0.3 && touchCount == 1 { networkService.sendClick(); flashNow() }
                    touchCount = 0
                }
            )
            .overlay(alignment: .center) {
                if flash { Color.white.opacity(0.25).ignoresSafeArea().allowsHitTesting(false).transition(.opacity) }
            }
            .overlay(alignment: .center) {
                VStack(spacing: 6) {
                    Image(systemName: "hand.point.up.fill").font(.system(size: 36)).foregroundColor(.white.opacity(0.3))
                    Text("Drag to move cursor").font(.caption).foregroundColor(.white.opacity(0.3))
                    Text("Two fingers to scroll").font(.caption2).foregroundColor(.white.opacity(0.2))
                }
                .allowsHitTesting(false)
                .opacity(networkService.currentFrame != nil ? 0 : 1)
            }
    }

    private func tapCheck() {
        let n = Date()
        if n.timeIntervalSince(lastTap) < 0.3 { touchCount += 1; if touchCount >= 2 { networkService.sendDoubleClick(); flashNow(); touchCount = 0 } }
        else { touchCount = 1 }
        lastTap = n
    }

    private func flashNow() {
        withAnimation(.easeOut(duration: 0.1)) { flash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { withAnimation(.easeIn(duration: 0.05)) { flash = false } }
    }
}
