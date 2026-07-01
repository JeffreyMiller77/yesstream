import SwiftUI

struct DesktopControlsView: View {
    @ObservedObject var networkService: NetworkService
    let screenSize: CGSize
    @AppStorage("mouseSensitivity") private var sensitivity: Double = 1.0

    @State private var lastTap = Date.distantPast
    @State private var down = false
    @State private var taps = 0
    @State private var flash = false

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { v in
                    let x = (v.location.x / screenSize.width) * networkService.screenWidth * sensitivity
                    let y = ((v.location.y - 50) / (screenSize.height - 100)) * networkService.screenHeight * sensitivity
                    networkService.sendMouseMove(x: max(0, min(networkService.screenWidth, x)), y: max(0, min(networkService.screenHeight, y)))
                    if !down {
                        down = true; let n = Date()
                        if n.timeIntervalSince(lastTap) < 0.3 { taps += 1; if taps >= 2 { networkService.sendClick(); taps = 0; flashNow() } }
                        else { taps = 1 }; lastTap = n
                    }
                }
                .onEnded { _ in
                    down = false; let n = Date()
                    if n.timeIntervalSince(lastTap) < 0.3 && taps == 1 { networkService.sendClick(); flashNow() }
                    taps = 0
                }
            )
            .overlay(alignment: .center) {
                if flash { Color.white.opacity(0.25).ignoresSafeArea().allowsHitTesting(false).transition(.opacity) }
            }
            .overlay(alignment: .center) {
                VStack(spacing: 6) {
                    Image(systemName: "hand.point.up.fill").font(.system(size: 36)).foregroundColor(.white.opacity(0.3))
                    Text("Touch to move cursor").font(.caption).foregroundColor(.white.opacity(0.3))
                    Text("Tap to click  ·  Double-tap = double-click").font(.caption2).foregroundColor(.white.opacity(0.2))
                }
                .allowsHitTesting(false)
                .opacity(networkService.currentFrame != nil ? 0 : 1)
            }
    }

    private func flashNow() {
        withAnimation(.easeOut(duration: 0.1)) { flash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { withAnimation(.easeIn(duration: 0.05)) { flash = false } }
    }
}
