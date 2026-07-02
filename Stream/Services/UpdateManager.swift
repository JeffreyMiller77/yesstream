import Foundation

class UpdateManager: ObservableObject {
    @Published var updateState: UpdateState = .idle

    enum UpdateState: Equatable {
        case idle
        case available(serverVersion: String, fileCount: Int)
        case downloading(current: Int, total: Int)
        case applying
        case done(version: String)
    }

    private let fileManager = FileManager.default
    private let versionKey = "stream_resource_version"

    var currentVersion: String {
        UserDefaults.standard.string(forKey: versionKey) ?? "0"
    }

    private var resourcesDir: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("StreamResources", isDirectory: true)
    }

    func ensureResourcesDir() {
        try? fileManager.createDirectory(at: resourcesDir, withIntermediateDirectories: true)
    }

    func applyFile(path: String, base64Data: String) -> Bool {
        ensureResourcesDir()
        let fileURL = resourcesDir.appendingPathComponent(path)
        let dir = fileURL.deletingLastPathComponent()
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let data = Data(base64Encoded: base64Data) else { return false }
        do {
            try data.write(to: fileURL)
            return true
        } catch {
            return false
        }
    }

    func finalizeUpdate(version: String) {
        UserDefaults.standard.set(version, forKey: versionKey)
    }

    func loadJSON<T: Decodable>(_ path: String) -> T? {
        let url = resourcesDir.appendingPathComponent(path)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func loadText(_ path: String) -> String? {
        let url = resourcesDir.appendingPathComponent(path)
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
