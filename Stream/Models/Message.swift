import Foundation

struct ControlMessage: Codable {
    let type: String
    let key: String?
    let x: Double?
    let y: Double?
    let dx: Double?
    let dy: Double?
    let text: String?
    let screenWidth: Double?
    let screenHeight: Double?
    let quality: Int?
    let fps: Int?
    let resourceVersion: String?
    let fileCount: Int?
    let path: String?
    let data: String?

    init(type: String, key: String? = nil, x: Double? = nil, y: Double? = nil,
         dx: Double? = nil, dy: Double? = nil, text: String? = nil,
         screenWidth: Double? = nil, screenHeight: Double? = nil,
         quality: Int? = nil, fps: Int? = nil,
         resourceVersion: String? = nil, fileCount: Int? = nil,
         path: String? = nil, data: String? = nil) {
        self.type = type; self.key = key; self.x = x; self.y = y
        self.dx = dx; self.dy = dy; self.text = text
        self.screenWidth = screenWidth; self.screenHeight = screenHeight
        self.quality = quality; self.fps = fps
        self.resourceVersion = resourceVersion; self.fileCount = fileCount
        self.path = path; self.data = data
    }
}

struct FavoriteServer: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var ip: String
    var port: Int
    init(id: UUID = UUID(), name: String, ip: String, port: Int = 8765) {
        self.id = id; self.name = name; self.ip = ip; self.port = port
    }
}
