import Foundation

/// Global constants for the AiCash application
struct Constants {
    /// Account history range in days for all provider usage requests
    static var AccountHistoryRange: Int {
        UserDefaults.standard.object(forKey: "accountHistoryRange") as? Int ?? 30
    }
    
    /// Page limit for history records in provider requests
    static var HistoryPageLimit: Int {
        UserDefaults.standard.object(forKey: "historyPageLimit") as? Int ?? 100
    }
}
