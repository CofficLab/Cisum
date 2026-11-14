
import Foundation
import SwiftUI

/// 通用日志条目模型
public struct MagicLogEntry: Identifiable {
    public let id = UUID()
    public let message: String
    public let originalMessage: String
    public let level: Level
    public let timestamp: Date
    public let caller: String
    public let line: Int?
    
    public init(
        message: String, 
        level: Level, 
        caller: String = "", 
        line: Int? = nil,
        timestamp: Date = Date()
    ) {
        self.originalMessage = message
        self.message = Thread.currentQosDescription + " | " + message.withContextEmoji
        self.level = level
        self.caller = caller
        self.line = line
        self.timestamp = timestamp
    }
    
    public enum Level {
        case info
        case warning
        case error
        case debug
        
        public var color: Color {
            switch self {
            case .info: return .primary
            case .warning: return .orange
            case .error: return .red
            case .debug: return .blue
            }
        }
        
        public var icon: String {
            switch self {
            case .info: return "info.circle"
            case .warning: return "exclamationmark.triangle"
            case .error: return "xmark.circle"
            case .debug: return "doc.text.magnifyingglass"
            }
        }
    }
}
