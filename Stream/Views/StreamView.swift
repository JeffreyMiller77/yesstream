import SwiftUI

struct StreamView: View {
    @ObservedObject var networkService: NetworkService
    @State private var gameMode = true
    @State private var showKeyboard = false
    @State private var showSettings = false
    @State private var showGamePicker = false

    private let games = ["default", "minecraft", "roblox"]

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
                    if gameMode && networkService.selectedGame != "default" {
                        GameControlsView(networkService: networkService, screenSize: geo.size, game: networkService.selectedGame)
                    } else if gameMode {
                        GameControlsView(networkService: networkService, screenSize: geo.size, game: "default")
                    } else {
                        DesktopControlsView(networkService: networkService, screenSize: geo.size)
                    }
                }
            }
            .overlay(alignment: .top) { topBar(safeTop: geo.safeAreaInsets.top) }
            .overlay(alignment: .bottom) {
                if showKeyboard { KeyboardView(networkService: networkService).transition(.move(edge: .bottom)) }
            }
            .overlay(alignment: .bottomLeading) { gameStrip }
            .sheet(isPresented: $showSettings) { SettingsView(networkService: networkService) }
            .alert("Game Launched", isPresented: $showLaunchAlert, actions: { Button("OK") { } }, message: {
                Text(networkService.gameLaunchResult?.ok == true ? "Game opened on PC" : "Could not launch game")
            })
            .confirmationDialog("Select Game Profile", isPresented: $showGamePicker, titleVisibility: .visible) {
                Button("Default") { networkService.selectedGame = "default" }
                Button("Minecraft") { networkService.selectedGame = "minecraft" }
                Button("Roblox") { networkService.selectedGame = "roblox" }
                Button("Cancel", role: .cancel) { }
            }
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
                if networkService.pingMs > 0 { Text("\(Int(networkService.pingMs))ms").font(.caption2).foregroundColor(.white.opacity(0.7)) }
            }
            .padding(.horizontal, 8).padding(.vertical, 4).background(.ultraThinMaterial).cornerRadius(12)
            if networkService.watchMode {
                Text("WATCH").font(.caption2).bold().foregroundColor(.yellow)
                    .padding(.horizontal, 8).padding(.vertical, 4).background(.ultraThinMaterial).cornerRadius(12)
            }
            Spacer()
            Group {
                tb("gamecontroller.fill") { gameMode.toggle() }
                tb("rectangle.3.group") { showGamePicker.toggle() }
                tb(networkService.watchMode ? "eye.fill" : "eye") { networkService.setWatchMode(!networkService.watchMode) }
                tb("keyboard") { showKeyboard.toggle() }
                tb("gearshape") { showSettings = true }
            }
        }
        .padding(.horizontal, 8).padding(.top, safeTop + 4)
    }

    private var gameStrip: some View {
        HStack(spacing: 6) {
            Button(action: { networkService.launchGame("minecraft") }) {
                HStack(spacing: 4) {
                    Image(systemName: "cube.fill").font(.caption2)
                    Text("MC").font(.caption2).bold()
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.green.opacity(0.3)).cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.4), lineWidth: 1))
            }
            Button(action: { networkService.launchGame("roblox") }) {
                HStack(spacing: 4) {
                    Image(systemName: "gamecontroller.fill").font(.caption2)
                    Text("RBX").font(.caption2).bold()
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.red.opacity(0.3)).cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.4), lineWidth: 1))
            }
            if networkService.selectedGame != "default" {
                Text(networkService.selectedGame.uppercased()).font(.caption2).foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 8).padding(.vertical, 4).background(.ultraThinMaterial).cornerRadius(10)
            }
        }
        .padding(.leading, 12).padding(.bottom, 88)
    }

    private var showLaunchAlert: Binding<Bool> {
        Binding {
            networkService.gameLaunchResult != nil
        } set: { if !$0 { networkService.gameLaunchResult = nil } }
    }

    private func tb(_ icon: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Image(systemName: icon).font(.system(size: 13)).foregroundColor(.white)
                .frame(width: 30, height: 30).background(.ultraThinMaterial).cornerRadius(15)
        }
    }
}
