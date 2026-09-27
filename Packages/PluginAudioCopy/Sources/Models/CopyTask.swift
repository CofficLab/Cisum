import Foundation
import CisumUIComponents
import MagicKit
import LumiUI
import SwiftData
import SwiftUI

@Model
class CopyTask {
    static let emoji: String = "🍁"

    var bookmark: Data
    var destination: URL
    var createdAt: Date
    var error: String = ""
    var isRunning: Bool = false
    var originalFilename: String // Store original filename since URL is gone

    var title: String { originalFilename }
    var time: String { Date.now }
    var message: String {
        if isRunning {
            return String(localized: "In Progress", bundle: .module)
        }
        if error.isEmpty {
            return String(localized: "Waiting to Copy", bundle: .module)
        }
        return error
    }

    init(bookmark: Data, destination: URL, originalFilename: String) {
        self.bookmark = bookmark
        self.destination = destination
        self.createdAt = .now
        self.originalFilename = originalFilename
    }
}

// MARK: ID

extension CopyTask: Identifiable {
    var id: PersistentIdentifier { persistentModelID }
}

// 用于数据传输
struct CopyTaskDTO: Sendable {
    let bookmark: Data
    let destination: URL
    let error: String
    let originalFilename: String

    init(bookmark: Data, destination: URL, error: String = "", originalFilename: String) {
        self.bookmark = bookmark
        self.destination = destination
        self.error = error
        self.originalFilename = originalFilename
    }

    init(from model: CopyTask) {
        self.bookmark = model.bookmark
        self.destination = model.destination
        self.error = model.error
        self.originalFilename = model.originalFilename
    }
}
