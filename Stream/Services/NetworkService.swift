import UIKit

enum ConnectionState { case disconnected, connecting, connected }

class NetworkService: ObservableObject {
    private var webSocket: URLSessionWebSocketTask?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var pingTimer: Timer?
    private var isActive = false
    let updateManager = UpdateManager()
    private var pendingFiles: Int = 0

    @Published var connectionState: ConnectionState = .disconnected
    @Published var screenWidth: Double = 1920
    @Published var screenHeight: Double = 1080
    @Published var currentFrame: UIImage?
    @Published var frameRate: Double = 0
    @Published var errorMessage: String?
    @Published var targetQuality: Int = 50
    @Published var targetFPS: Int = 60
    @Published var updateState: UpdateManager.UpdateState = .idle

    private var frameCount = 0
    private var lastFrameTime = Date()

    func connect(to url: URL) {
        disconnect()
        connectionState = .connecting
        errorMessage = nil
        isActive = true
        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        let session = URLSession(configuration: .ephemeral)
        webSocket = session.webSocketTask(with: req)
        webSocket?.resume()
        receiveMessage()
        startPing()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            if self?.connectionState == .connecting {
                self?.errorMessage = "Connection timed out"
                self?.disconnect()
            }
        }
    }

    func disconnect() {
        isActive = false
        pingTimer?.invalidate()
        pingTimer = nil
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        DispatchQueue.main.async {
            self.connectionState = .disconnected
            self.currentFrame = nil
            self.frameRate = 0
            self.errorMessage = nil
        }
    }

    private func startPing() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.send(ControlMessage(type: "ping"))
        }
    }

    private func send(_ m: ControlMessage) {
        guard isActive, let d = try? encoder.encode(m), let s = String(data: d, encoding: .utf8) else { return }
        webSocket?.send(.string(s)) { _ in }
    }

    func sendPerformanceSettings() {
        send(ControlMessage(type: "set_performance", quality: targetQuality, fps: targetFPS))
    }

    func sendMouseMove(x: Double, y: Double) { send(ControlMessage(type: "mouse_move", x: x, y: y)) }
    func sendRelativeMove(dx: Double, dy: Double) { send(ControlMessage(type: "mouse_move_relative", dx: dx, dy: dy)) }
    func sendClick() { send(ControlMessage(type: "mouse_click")) }
    func sendDoubleClick() { send(ControlMessage(type: "mouse_doubleclick")) }
    func sendRightClick() { send(ControlMessage(type: "mouse_rightclick")) }
    func sendScroll(dy: Double) { send(ControlMessage(type: "mouse_scroll", dy: dy)) }
    func sendKeyDown(_ k: String) { send(ControlMessage(type: "key_down", key: k)) }
    func sendKeyUp(_ k: String) { send(ControlMessage(type: "key_up", key: k)) }
    func sendTap(_ k: String) { send(ControlMessage(type: "key_tap", key: k)) }
    func sendText(_ t: String) { send(ControlMessage(type: "type_text", text: t)) }

    func checkResources() {
        send(ControlMessage(type: "check_resources", resourceVersion: updateManager.currentVersion))
    }

    func requestUpdate() {
        pendingFiles = 0
        send(ControlMessage(type: "request_update"))
    }

    private func receiveMessage() {
        webSocket?.receive { [weak self] r in
            guard let self = self else { return }
            switch r {
            case .success(let m):
                switch m {
                case .data(let d):
                    DispatchQueue.main.async {
                        if case .downloading = self.updateState { return }
                        if let img = UIImage(data: d) {
                            self.currentFrame = img
                            self.frameCount += 1
                            let now = Date()
                            if now.timeIntervalSince(self.lastFrameTime) >= 1.0 {
                                let e = now.timeIntervalSince(self.lastFrameTime)
                                self.frameRate = e > 0 ? Double(self.frameCount) / e : 0
                                self.frameCount = 0
                                self.lastFrameTime = now
                            }
                        }
                    }
                case .string(let t):
                    guard let d = t.data(using: .utf8),
                          let msg = try? self.decoder.decode(ControlMessage.self, from: d) else { break }
                    DispatchQueue.main.async {
                        switch msg.type {
                        case "connected":
                            if let w = msg.screenWidth { self.screenWidth = w }
                            if let h = msg.screenHeight { self.screenHeight = h }
                            self.connectionState = .connected
                            self.errorMessage = nil
                            self.sendPerformanceSettings()
                            self.checkResources()
                        case "up_to_date":
                            self.updateState = .idle
                        case "update_available":
                            let sv = msg.resourceVersion ?? "?"
                            self.updateState = .available(serverVersion: sv, fileCount: msg.fileCount ?? 0)
                        case "update_start":
                            self.pendingFiles = 0
                            self.updateState = .downloading(current: 0, total: msg.fileCount ?? 0)
                        case "update_file":
                            if let path = msg.path, let data = msg.data {
                                _ = self.updateManager.applyFile(path: path, base64Data: data)
                            }
                            if case .downloading(let cur, let total) = self.updateState {
                                self.updateState = .downloading(current: cur + 1, total: total)
                            }
                        case "update_complete":
                            let ver = msg.resourceVersion ?? self.updateManager.currentVersion
                            self.updateManager.finalizeUpdate(version: ver)
                            self.updateState = .done(version: ver)
                        case "pong":
                            break
                        default:
                            break
                        }
                    }
                @unknown default: break
                }
                if self.isActive { self.receiveMessage() }
            case .failure:
                DispatchQueue.main.async {
                    if self.isActive { self.errorMessage = "Connection lost"; self.connectionState = .disconnected }
                }
            }
        }
    }
}
