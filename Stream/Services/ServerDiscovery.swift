import Foundation

class ServerDiscovery: NSObject, ObservableObject {
    private var browser: NetServiceBrowser?
    private var resolved = Set<NetService>()

    @Published var discoveredServers: [NetService] = []
    @Published var favorites: [FavoriteServer] = []
    @Published var isSearching = false

    private let key = "stream_favs_v3"

    override init() { super.init(); load() }

    func startSearching() {
        stopSearching()
        isSearching = true
        resolved.removeAll()
        browser = NetServiceBrowser()
        browser?.delegate = self
        browser?.searchForServices(ofType: "_stream._tcp", inDomain: "local.")
    }

    func stopSearching() { browser?.stop(); browser = nil; isSearching = false }
    func refresh() { startSearching() }

    func addFavorite(_ s: FavoriteServer) {
        if !favorites.contains(where: { $0.ip == s.ip && $0.port == s.port }) { favorites.append(s); save() }
    }
    func removeFavorite(_ id: UUID) { favorites.removeAll { $0.id == id }; save() }

    private func load() {
        guard let d = UserDefaults.standard.data(forKey: key), let f = try? JSONDecoder().decode([FavoriteServer].self, from: d) else { return }
        favorites = f
    }
    private func save() {
        guard let d = try? JSONEncoder().encode(favorites) else { return }
        UserDefaults.standard.set(d, forKey: key)
    }
}

extension ServerDiscovery: NetServiceBrowserDelegate {
    func netServiceBrowser(_: NetServiceBrowser, didFind s: NetService, moreComing: Bool) {
        s.delegate = self; s.resolve(withTimeout: 5)
    }
    func netServiceBrowser(_: NetServiceBrowser, didRemove s: NetService, moreComing: Bool) {
        resolved.remove(s); DispatchQueue.main.async { self.discoveredServers = Array(self.resolved) }
    }
    func netServiceBrowserDidStopSearch(_: NetServiceBrowser) { DispatchQueue.main.async { self.isSearching = false } }
}

extension ServerDiscovery: NetServiceDelegate {
    func netServiceDidResolveAddress(_ sender: NetService) {
        DispatchQueue.main.async { self.resolved.insert(sender); self.discoveredServers = Array(self.resolved) }
    }
    func netService(_: NetService, didNotResolve e: [String: NSNumber]) { print("Resolve failed: \(e)") }
}
