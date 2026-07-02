import SwiftUI

struct ConnectView: View {
    @ObservedObject var networkService: NetworkService
    @StateObject private var discovery = ServerDiscovery()
    @State private var manualIP = ""
    @State private var manualPort = "8765"
    @State private var manualName = ""
    @State private var showManual = false

    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    Image(systemName: "antenna.radiowaves.left.and.right").font(.system(size: 44)).foregroundColor(.blue)
                    Text("Stream").font(.largeTitle).bold()
                    Text("v3 – PC Remote").foregroundColor(.secondary).font(.subheadline)
                    if networkService.connectionState == .connecting { ProgressView("Connecting...") }
                    if let e = networkService.errorMessage { Text(e).foregroundColor(.red).font(.caption) }
                    updateStatusView
                }.frame(maxWidth: .infinity).padding(.vertical, 8)
            }

            if !discovery.favorites.isEmpty {
                Section("Favorites") {
                    ForEach(discovery.favorites) { fav in
                        Button(action: { connectTo(ip: fav.ip, port: fav.port) }) {
                            HStack {
                                Image(systemName: "star.fill").foregroundColor(.yellow)
                                VStack(alignment: .leading) { Text(fav.name).foregroundColor(.primary); Text("\(fav.ip):\(fav.port)").font(.caption).foregroundColor(.secondary) }
                                Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing) { Button(role: .destructive) { discovery.removeFavorite(fav.id) } label: { Label("Delete", systemImage: "trash") } }
                    }
                }
            }

            Section {
                if discovery.isSearching && discovery.discoveredServers.isEmpty {
                    HStack { ProgressView().scaleEffect(0.8); Text("Searching...").foregroundColor(.secondary).padding(.leading, 6) }
                }
                ForEach(discovery.discoveredServers, id: \.hash) { s in
                    Button(action: {
                        guard let h = s.hostName else { return }
                        let c = h.hasSuffix(".") ? String(h.dropLast()) : h
                        connectTo(ip: c, port: s.port)
                    }) {
                        HStack {
                            Image(systemName: "desktopcomputer").foregroundColor(.blue)
                            VStack(alignment: .leading) { Text(s.name).foregroundColor(.primary); if let h = s.hostName { Text(h).font(.caption).foregroundColor(.secondary) } }
                            Spacer(); Text("\(s.port)").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            guard let h = s.hostName else { return }
                            let c = h.hasSuffix(".") ? String(h.dropLast()) : h
                            discovery.addFavorite(FavoriteServer(name: s.name, ip: c, port: s.port))
                        } label: { Label("Save", systemImage: "star") }.tint(.yellow)
                    }
                }
            } header: {
                HStack {
                    Text("On Your Network"); Spacer()
                    if discovery.isSearching { ProgressView().scaleEffect(0.6) }
                    Button(action: { discovery.refresh() }) { Image(systemName: "arrow.clockwise").font(.caption) }
                }
            }

            Section {
                Button(action: { showManual.toggle() }) { Label("Manual Connection", systemImage: "keyboard") }
                if showManual {
                    TextField("Name (e.g. Gaming PC)", text: $manualName)
                    TextField("IP Address", text: $manualIP).keyboardType(.numbersAndPunctuation).autocapitalization(.none).disableAutocorrection(true)
                    TextField("Port", text: $manualPort).keyboardType(.numberPad)
                    HStack {
                        Button("Connect") { connectTo(ip: manualIP, port: Int(manualPort) ?? 8765) }.disabled(manualIP.isEmpty).buttonStyle(.borderedProminent)
                        Button("Save Favorite") {
                            let p = Int(manualPort) ?? 8765
                            discovery.addFavorite(FavoriteServer(name: manualName.isEmpty ? manualIP : manualName, ip: manualIP, port: p))
                            showManual = false; manualIP = ""; manualPort = "8765"; manualName = ""
                        }.disabled(manualIP.isEmpty).buttonStyle(.bordered)
                    }
                }
            } header: { Text("Connect") }
        }
        .listStyle(.insetGrouped)
        .onAppear { discovery.startSearching() }
        .onDisappear { discovery.stopSearching() }
        .alert("Resources Update Available", isPresented: $showUpdateAlert, actions: {
            Button("Update Now") { networkService.requestUpdate() }
            Button("Later", role: .cancel) { }
        }, message: {
            if case .available(let sv, let fc) = networkService.updateState {
                Text("Version \(sv) (\(fc) files) is available. Update now?")
            } else {
                Text("A new version is available.")
            }
        })
    }

    @ViewBuilder
    private var updateStatusView: some View {
        switch networkService.updateState {
        case .downloading(let current, let total):
            VStack(spacing: 4) {
                ProgressView(value: Double(current), total: Double(total))
                    .progressViewStyle(.linear)
                Text("Updating resources... \(current)/\(total)").font(.caption).foregroundColor(.secondary)
            }.padding(.top, 6)
        case .done(let v):
            Text("Resources updated to v\(v)").font(.caption).foregroundColor(.green).padding(.top, 4)
        default:
            EmptyView()
        }
    }

    private var showUpdateAlert: Binding<Bool> {
        Binding {
            if case .available = networkService.updateState { return true }
            return false
        } set: { if !$0 { networkService.updateState = .idle } }
    }

    private func connectTo(ip: String, port: Int) {
        let c = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: "ws://\(c):\(port)") else { networkService.errorMessage = "Invalid address"; return }
        networkService.connect(to: url)
    }
}
