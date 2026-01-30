import Foundation
import SwiftUI

class BLTProvider: NSObject, AIProviderProtocol, ObservableObject {
    let id = UUID()
    @Published var name = "BLT"
    let symbol = "BLT"
    @Published var fullName = "BLT API"
    
    @Published var balance: Double = 0.0
    @Published var todayUsage: Double = 0.0
    @Published var usageHistory: [ProviderUsage] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    // Detailed usage
    @Published var includedUsage: Double = 0.0
    @Published var includedLimit: Double = 0.0
    @Published var onDemandUsage: Double = 0.0
    @Published var usageEvents: [UsageEvent] = []
    
    @Published var userId: String = ""
    @Published var token: String = ""
    
    private let apiEndpoint = "https://api.bltcy.ai/api/user/self"
    private let historyEndpoint = "https://api.bltcy.ai/api/data/self"
    
    func login() async {
        Log.info("[BLT] Login method called.")
    }
    
    func fetchData() async {
        guard !userId.isEmpty, !token.isEmpty else {
            await MainActor.run {
                self.errorMessage = "User ID and Token are required"
            }
            return
        }
        
        Log.info("[BLT] Starting data fetch...")
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // 1. Fetch User Info
            try await fetchUserInfo()
            
            // 2. Fetch History
            try await fetchHistory()
            
            await MainActor.run {
                self.isLoading = false
            }
        } catch {
            Log.error("[BLT] Fetch failed: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func fetchUserInfo() async throws {
        guard let url = URL(string: apiEndpoint) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(userId, forHTTPHeaderField: "New-API-User")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "BLTProvider", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw NSError(domain: "BLTProvider", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unauthorized. Please check your credentials."])
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "BLTProvider", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error \(httpResponse.statusCode)"])
        }
        
        let decoder = JSONDecoder()
        let bltResponse = try decoder.decode(BLTResponse.self, from: data)
        
        if bltResponse.success {
            await MainActor.run {
                self.balance = Double(bltResponse.data.quota) / 500000.0
                self.includedUsage = Double(bltResponse.data.used_quota) / 500000.0
                Log.info("[BLT] User info fetch successful. Balance: \(self.balance)")
            }
        } else {
            throw NSError(domain: "BLTProvider", code: 0, userInfo: [NSLocalizedDescriptionKey: bltResponse.message])
        }
    }
    
    private func fetchHistory() async throws {
        let now = Int(Date().timeIntervalSince1970)
        let sevenDaysAgo = now - (7 * 24 * 60 * 60)
        
        var components = URLComponents(string: historyEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "start_timestamp", value: "\(sevenDaysAgo)"),
            URLQueryItem(name: "end_timestamp", value: "\(now)"),
            URLQueryItem(name: "default_time", value: "day")
        ]
        
        guard let url = components.url else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue(userId, forHTTPHeaderField: "New-API-User")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return
        }
        
        let decoder = JSONDecoder()
        let historyResponse = try decoder.decode(BLTHistoryResponse.self, from: data)
        
        if historyResponse.success {
            await MainActor.run {
                // Group by date to show daily usage in the chart
                let calendar = Calendar.current
                var dailyUsage: [Date: Double] = [:]
                
                for item in historyResponse.data {
                    let date = Date(timeIntervalSince1970: TimeInterval(item.created_at))
                    let startOfDay = calendar.startOfDay(for: date)
                    let amount = Double(item.quota) / 500000.0
                    dailyUsage[startOfDay, default: 0] += amount
                }
                
                self.usageHistory = dailyUsage.map { date, amount in
                    ProviderUsage(date: date, amount: amount)
                }.sorted(by: { $0.date < $1.date })
                
                // Calculate today's usage
                self.todayUsage = dailyUsage.filter { calendar.isDateInToday($0.key) }
                    .map { $0.value }
                    .first ?? 0.0
                
                // Map to UsageEvents for the table
                self.usageEvents = historyResponse.data.map { item in
                    let date = Date(timeIntervalSince1970: TimeInterval(item.created_at))
                    return UsageEvent(
                        date: self.formatDate(date),
                        user: item.username,
                        type: "Chat",
                        model: item.model_name,
                        inputTokens: item.token_used,
                        outputTokens: 0,
                        cacheTokens: 0,
                        cost: Double(item.quota) / 5000.0 // UsageEvent cost is in cents, quota / 500,000 * 100 = quota / 5,000
                    )
                }.sorted(by: { $0.date > $1.date }) // Newest first
                
                Log.info("[BLT] History fetch successful. Points: \(self.usageHistory.count), Events: \(self.usageEvents.count)")
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, hh:mm a"
        return formatter.string(from: date)
    }
}

// BLT API Response Structures
struct BLTResponse: Codable {
    let data: BLTUserData
    let message: String
    let success: Bool
}

struct BLTUserData: Codable {
    let id: Int
    let username: String
    let display_name: String
    let email: String
    let quota: Int
    let used_quota: Int
    let request_count: Int
    let group: String
    let aff_quota: Int
    let aff_history_quota: Int
}

struct BLTHistoryResponse: Codable {
    let success: Bool
    let message: String
    let data: [BLTHistoryItem]
}

struct BLTHistoryItem: Codable {
    let id: Int
    let user_id: Int
    let username: String
    let model_name: String
    let created_at: Int
    let token_used: Int
    let count: Int
    let quota: Int
}
