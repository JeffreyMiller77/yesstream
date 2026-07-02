import SwiftUI

struct GameControlsView: View {
    @ObservedObject var networkService: NetworkService
    let screenSize: CGSize
    let game: String
    @AppStorage("mouseSensitivity") private var sensitivity: Double = 1.0

    @State private var activeWASD = Set<String>()
    @State private var wasdOff = CGSize.zero
    private let stickR: CGFloat = 55
    private let deadZ: CGFloat = 15

    private var layout: [(String, String)] {
        switch game {
        case "minecraft":
            return [("Jump","space"),("Sprint","shift"),("Crouch","ctrl"),("Inventory","e"),("Attack","mouse_click")]
        case "roblox":
            return [("Jump","space"),("Sprint","shift"),("Crouch","ctrl"),("Interact","e"),("Tool","q")]
        default:
            return [("Jump","space"),("Sprint","shift"),("Crouch","ctrl"),("Interact","e")]
        }
    }

    var body: some View {
        ZStack {
            VStack {
                Spacer()
                HStack { wasdJoystick.padding(.leading, 16).padding(.bottom, 130); Spacer() }
            }
            VStack {
                Spacer()
                HStack { Spacer(); mouseLook.frame(width: screenSize.width * 0.44, height: screenSize.height * 0.5).padding(.trailing, 6).padding(.bottom, 110) }
            }
            VStack {
                Spacer()
                actionButtons.padding(.bottom, 28)
            }
            VStack {
                Spacer()
                HStack { Spacer(); clickBtn.padding(.trailing, 16).padding(.bottom, 110) }
            }
        }
        .ignoresSafeArea()
    }

    private var wasdJoystick: some View {
        ZStack {
            Circle().fill(Color.black.opacity(0.35)).frame(width: stickR * 2, height: stickR * 2)
            VStack(spacing: 1) {
                Text("W").font(.caption2).bold().foregroundColor(.white.opacity(0.4))
                HStack(spacing: 2) { Text("A").font(.caption2).bold().foregroundColor(.white.opacity(0.4)); Circle().fill(Color.clear).frame(width: 18, height: 18); Text("D").font(.caption2).bold().foregroundColor(.white.opacity(0.4)) }
                Text("S").font(.caption2).bold().foregroundColor(.white.opacity(0.4))
            }.allowsHitTesting(false)
            Circle().fill(Color.white.opacity(0.45)).frame(width: 42, height: 42).offset(wasdOff)
        }
        .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { v in
                let d = sqrt(v.translation.width * v.translation.width + v.translation.height * v.translation.height)
                let c = min(d, stickR); let a = atan2(v.translation.height, v.translation.width)
                wasdOff = CGSize(width: cos(a) * c, height: sin(a) * c)
                if d < deadZ { releaseWASD(); return }
                let deg = (a * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
                var next = Set<String>()
                if deg >= 225 && deg < 315 { next.insert("w") }
                if deg >= 135 && deg < 225 { next.insert("a") }
                if deg >= 45 && deg < 135 { next.insert("s") }
                if deg >= 315 || deg < 45 { next.insert("d") }
                for k in activeWASD.subtracting(next) { networkService.sendKeyUp(k) }
                for k in next.subtracting(activeWASD) { networkService.sendKeyDown(k) }
                activeWASD = next
            }
            .onEnded { _ in withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { wasdOff = .zero }; releaseWASD() }
        )
    }

    private func releaseWASD() { for k in activeWASD { networkService.sendKeyUp(k) }; activeWASD.removeAll() }

    private var mouseLook: some View {
        RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.2))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 1))
            .overlay(VStack(spacing: 3) { Image(systemName: "arrow.up.backward.and.arrow.down.forward").font(.title3).foregroundColor(.white.opacity(0.5)); Text("Look").font(.caption).foregroundColor(.white.opacity(0.4)) })
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                networkService.sendRelativeMove(dx: v.translation.width * sensitivity * 0.4, dy: v.translation.height * sensitivity * 0.4)
            })
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            ForEach(layout, id: \.0) { l,k in
                if k == "mouse_click" {
                    Text(l).font(.system(size: 9, weight: .semibold)).foregroundColor(.white)
                        .frame(width: 58, height: 36).background(Color.blue.opacity(0.4)).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.15), lineWidth: 1))
                        .onTouchDownUp({ networkService.sendKeyDown("attack") }, { networkService.sendClick() })
                } else {
                    Text(l).font(.system(size: 9, weight: .semibold)).foregroundColor(.white)
                        .frame(width: 58, height: 36).background(Color.black.opacity(0.4)).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.15), lineWidth: 1))
                        .onTouchDownUp({ networkService.sendKeyDown(k) }, { networkService.sendKeyUp(k) })
                }
            }
        }.padding(.horizontal, 8)
    }

    private var clickBtn: some View {
        Button(action: { networkService.sendClick() }) {
            Text("CLICK").font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                .frame(width: 56, height: 56).background(Circle().fill(Color.blue.opacity(0.5)))
                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
        }
    }
}

struct TouchDownUp: ViewModifier {
    let down: () -> Void; let up: () -> Void
    func body(content: Content) -> some View {
        content.simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in down() }.onEnded { _ in up() })
    }
}

extension View {
    func onTouchDownUp(_ d: @escaping () -> Void, _ u: @escaping () -> Void) -> some View {
        self.modifier(TouchDownUp(down: d, up: u))
    }
}
