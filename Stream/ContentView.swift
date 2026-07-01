import SwiftUI

struct ContentView: View {
    @StateObject private var networkService = NetworkService()

    var body: some View {
        switch networkService.connectionState {
        case .disconnected, .connecting:
            ConnectView(networkService: networkService)
        case .connected:
            StreamView(networkService: networkService)
        }
    }
}
