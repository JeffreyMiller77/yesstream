import SwiftUI

struct SettingsView: View {
    @ObservedObject var networkService: NetworkService
    @Environment(\.dismiss) private var dismiss
    @AppStorage("mouseSensitivity") private var sensitivity: Double = 1.0
    @AppStorage("streamQuality") private var quality: Double = 50
    @AppStorage("streamFPS") private var fps: Double = 60

    var body: some View {
        NavigationView {
            Form {
                Section("Connection") {
                    HStack { Text("Status"); Spacer(); Text("Connected").foregroundColor(.green) }
                    HStack { Text("PC Screen"); Spacer(); Text("\(Int(networkService.screenWidth)) x \(Int(networkService.screenHeight))").foregroundColor(.secondary) }
                    if networkService.frameRate > 0 { HStack { Text("Stream FPS"); Spacer(); Text(String(format: "%.0f", networkService.frameRate)).foregroundColor(.secondary) } }
                    Button("Disconnect", role: .destructive) { networkService.disconnect(); dismiss() }
                }
                Section("Performance") {
                    VStack { HStack { Text("Quality"); Spacer(); Text("\(Int(quality))%").foregroundColor(.secondary) }; Slider(value: $quality, in: 10...90, step: 5); Text("Lower = smoother on slow WiFi").font(.caption).foregroundColor(.secondary) }
                    VStack { HStack { Text("Max FPS"); Spacer(); Text("\(Int(fps))").foregroundColor(.secondary) }; Slider(value: $fps, in: 15...60, step: 5) }
                    Button("Apply") { networkService.targetQuality = Int(quality); networkService.targetFPS = Int(fps); networkService.sendPerformanceSettings() }.buttonStyle(.borderedProminent)
                }
                Section("Controls") {
                    VStack { HStack { Text("Mouse Sensitivity"); Spacer(); Text(String(format: "%.1f", sensitivity)).foregroundColor(.secondary) }; Slider(value: $sensitivity, in: 0.2...3.0) }
                    Text("Desktop: Touch = absolute cursor\nGame: Right side = look (relative)\nTap = click  ·  Double-tap = double-click").font(.caption).foregroundColor(.secondary)
                }
                Section("Action Keys") { Text("Jump=Space  Sprint=Shift  Crouch=Ctrl  Interact=E").font(.caption) }
                Section { Text("v3.0 – Screen stream + game controls + desktop trackpad").font(.caption).foregroundColor(.secondary) }
            }
            .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
