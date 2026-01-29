import Foundation
import OSLog

class Log {
    static let shared = Log()
    private let logger = os.Logger(subsystem: "com.csl.cool.AiCash", category: "App")
    
    private init() {}
    
    static func info(_ message: String) {
        shared.logger.info("\(message, privacy: .public)")
    }
    
    static func error(_ message: String) {
        shared.logger.error("\(message, privacy: .public)")
    }
    
    static func debug(_ message: String) {
        shared.logger.debug("\(message, privacy: .public)")
    }
    
    static func warning(_ message: String) {
        shared.logger.warning("\(message, privacy: .public)")
    }
}

