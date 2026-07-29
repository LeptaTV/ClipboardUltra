import Foundation
import SwiftData

@Model
final class ClipItem {
    var content: String
    var category: String
    var copiedAt: Date
    var isPinned: Bool
    var imageData: Data?
    var sourceApp: String?

    init(content: String, category: String, imageData: Data? = nil, sourceApp: String? = nil) {
        self.content = content
        self.category = category
        self.copiedAt = Date()
        self.isPinned = false
        self.imageData = imageData
        self.sourceApp = sourceApp
    }
}
