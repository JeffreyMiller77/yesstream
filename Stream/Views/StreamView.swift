import SwiftUI

struct StreamView: View {
    @ObservedObject var networkService: NetworkService
    @State private var gameMode = true
    @State private var showKeyboard = false
    @State private var showSettings = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let frame = networkService.currentFrame {
                    Image(uiImage: frame)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped().ignoresSafeArea()
                } else {
                    Color.black.ignoresSafeArea()
                    VStack(spacing: 10) { ProgressView().tint(.white); Text("Stream starting...").foregroundColor(.white) }
                }

                if networkService.currentFrame != nil {
                    if gameMode {
                        GameControlsView(networkService: networkService, screenSize: geo.size)
                    } else {
                        DesktopControlsView(networkService: networkService, screenSize: geo.size)
                    }
                }
            }
            .overlay(alignment: .top) { topBar(safeTop: geo.safeAreaInsets.top) }
            .overlay(alignment: .bottom) {
                if showKeyboard { KeyboardView(networkService: networkService).transition(.move(edge: .bottom)) }
            }
            .sheet(isPresented: $showSettings) { SettingsView(networkService: networkService) }
            .animation(.easeInOut(duration: 0.2), value: showKeyboard)
            .animation(.easeInOut(duration: 0.15), value: gameMode)
        }
        .ignoresSafeArea(.keyboard).statusBar(hidden: true)
    }

    @ViewBuilder
    private func topBar(safeTop: CGFloat) -> some View {
        HStack(spacing: 6) {
            HStack(spacing: 4) {
                Circle().fill(Color.green).frame(width: 6, height: 6)
                if networkService.frameRate > 0 { Text(String(format: "%.0f fps", networkService.frameRate)).font(.caption2).foregroundColor(.white) }
                else { Text("Live").font(.caption2).foregroundColor(.white) }
            }
            .padding(.horizontal, 8).padding(.vertical, 4).background(.ultraThinMaterial).cornerRadius(12)
            Spacer()
            Group {
                tb(gameMode ? "gamecontroller.fill" : "hand.point.up.fill") { gameMode.toggle() }
                tb("arrow.up.to.line") { networkService.sendDoubleClick() }
                tb("cursorarrow") { networkService.sendRightClick() }
                tb("keyboard") { showKeyboard.toggle() }
                tb("gearshape") { showSettings = true }
            }
        }
        .padding(.horizontal, 8).padding(.top, safeTop + 4)
    }

    private func tb(_ icon: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Image(systemName: icon).font(.system(size: 13)).foregroundColor(.white)
                .frame(width: 30, height: 30).background(.ultraThinMaterial).cornerRadius(15)
        }
    }
}
