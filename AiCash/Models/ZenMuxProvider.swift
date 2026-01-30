import Foundation
import SwiftUI

class ZenMuxProvider: NSObject, AIProviderProtocol, ObservableObject {
    let id = UUID()
    @Published var name = "ZenMux"
    let symbol = "ZEN"
    @Published var fullName = "ZenMux AI"
    
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
    
    @Published var token: String = ""
    @Published var curlCommand: String = ""
    
    // Extracted session info
    private var extractedCtoken: String?
    private var extractedSessionId: String?
    private var extractedSessionIdSig: String?
    
    private let apiEndpoint = "https://zenmux.ai/api/user/info"
    private let dailyCostEndpoint = "https://zenmux.ai/api/dashboard/cost/query/summary"
    private let historyEndpoint = "https://zenmux.ai/api/api_key/activity"
    
    func login() async {
        Log.info("[ZenMux] Login method called.")
    }
    
    private func parseCurlCommand() {
        Log.info("[ZenMux] Parsing cURL command for session info...")
        
        // Extract ctoken from URL
        if let ctokenRange = curlCommand.range(of: "ctoken=([^'\"&\\s]+)", options: .regularExpression) {
            let match = curlCommand[ctokenRange]
            extractedCtoken = String(match.replacingOccurrences(of: "ctoken=", with: ""))
            Log.info("[ZenMux] Extracted ctoken: \(extractedCtoken ?? "nil")")
        }
        
        // Extract sessionId from cookies (-b or --cookie)
        if let sessionIdRange = curlCommand.range(of: "sessionId=([^;\\s'\"&]+)", options: .regularExpression) {
            let match = curlCommand[sessionIdRange]
            extractedSessionId = String(match.replacingOccurrences(of: "sessionId=", with: ""))
            Log.info("[ZenMux] Extracted sessionId: \(extractedSessionId ?? "nil")")
        }
        
        // Extract sessionId.sig from cookies
        if let sigRange = curlCommand.range(of: "sessionId\\.sig=([^;\\s'\"&]+)", options: .regularExpression) {
            let match = curlCommand[sigRange]
            extractedSessionIdSig = String(match.replacingOccurrences(of: "sessionId.sig=", with: ""))
            Log.info("[ZenMux] Extracted sessionId.sig: \(extractedSessionIdSig ?? "nil")")
        }
    }
    
    func fetchData() async {
        guard !curlCommand.isEmpty else {
            await MainActor.run {
                self.errorMessage = "cURL command is required"
            }
            return
        }
        
        Log.info("[ZenMux] Starting data fetch...")
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        parseCurlCommand()
        
        guard let ctoken = extractedCtoken else {
            await MainActor.run {
                self.errorMessage = "Could not find ctoken in cURL command"
                self.isLoading = false
            }
            return
        }
        
        do {
            // 1. Fetch Balance
            try await fetchBalance(ctoken: ctoken)
            
            // 2. Fetch Daily Cost Summary
            try await fetchDailyCost(ctoken: ctoken)
            
            // 3. Fetch Detailed History Records
            try await fetchHistoryRecords(ctoken: ctoken)
            
            await MainActor.run {
                self.isLoading = false
            }
        } catch {
            Log.error("[ZenMux] Fetch failed: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func fetchBalance(ctoken: String) async throws {
        var components = URLComponents(string: apiEndpoint)!
        components.queryItems = [URLQueryItem(name: "ctoken", value: ctoken)]
        
        guard let url = components.url else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        
        let cookieHeader = constructCookieHeader(ctoken: ctoken)
        request.addValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.addValue("https://zenmux.ai/platform/cost", forHTTPHeaderField: "Referer")
        request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "ZenMuxProvider", code: 0, userInfo: [NSLocalizedDescriptionKey: "Balance API failed"])
        }
        
        let decoder = JSONDecoder()
        let zenResponse = try decoder.decode(ZenMuxResponse.self, from: data)
        
        if zenResponse.success, let userData = zenResponse.data {
            await MainActor.run {
                self.balance = userData.balance
            }
        }
    }
    
    private func fetchDailyCost(ctoken: String) async throws {
        var components = URLComponents(string: dailyCostEndpoint)!
        components.queryItems = [URLQueryItem(name: "ctoken", value: ctoken)]
        
        guard let url = components.url else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.addValue("https://zenmux.ai", forHTTPHeaderField: "Origin")
        
        let cookieHeader = constructCookieHeader(ctoken: ctoken)
        request.addValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.addValue("https://zenmux.ai/platform/cost", forHTTPHeaderField: "Referer")
        request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let todayStr = formatter.string(from: Date())
        
        let body: [String: Any] = [
            "queryDimension": "BIZ_DT",
            "queryTime": todayStr,
            "apiKeys": [],
            "modelSlugs": [],
            "endpointSlugs": []
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return
        }
        
        let decoder = JSONDecoder()
        let costResponse = try decoder.decode(ZenMuxCostResponse.self, from: data)
        
        if costResponse.success {
            await MainActor.run {
                let cost = Double(costResponse.data.totalCost) ?? 0.0
                self.todayUsage = cost
                
                // Add to history for sparkline
                self.usageHistory = [ProviderUsage(date: Date(), amount: cost)]
            }
        }
    }
    
    private func fetchHistoryRecords(ctoken: String) async throws {
        var allEvents: [ZenMuxHistoryItem] = []
        var currentPage = 1
        let targetCount = Constants.HistoryPageLimit
        
        while allEvents.count < targetCount {
            let pageEvents = try await fetchHistoryPage(ctoken: ctoken, page: currentPage)
            if pageEvents.isEmpty { break }
            
            allEvents.append(contentsOf: pageEvents)
            currentPage += 1
            
            // Prevent infinite loop
            if currentPage > 10 { break }
        }
        
        await MainActor.run {
            // Group by date to show daily usage in the chart
            let calendar = Calendar.current
            var dailyUsage: [Date: Double] = [:]
            
            for item in allEvents.prefix(targetCount) {
                let startOfDay = calendar.startOfDay(for: item.createdAt)
                let amount = Double(item.billAmount) ?? 0.0
                dailyUsage[startOfDay, default: 0] += amount
            }
            
            self.usageHistory = dailyUsage.map { date, amount in
                ProviderUsage(date: date, amount: amount)
            }.sorted(by: { $0.date < $1.date })
            
            self.usageEvents = Array(allEvents.prefix(targetCount)).map { item in
                let cost = Double(item.billAmount) ?? 0.0
                return UsageEvent(
                    date: self.formatDateForEvent(item.createdAt),
                    user: item.providerSlug,
                    type: "Chat",
                    model: item.modelSlug,
                    inputTokens: item.tokensPrompt,
                    outputTokens: item.tokensCompletion,
                    cacheTokens: 0,
                    cost: cost * 100.0 // cost is in USD, UsageEvent expects cents
                )
            }
            
            Log.info("[ZenMux] History records fetch successful. Points: \(self.usageHistory.count), Events: \(self.usageEvents.count)")
        }
    }
    
    private func fetchHistoryPage(ctoken: String, page: Int) async throws -> [ZenMuxHistoryItem] {
        var components = URLComponents(string: historyEndpoint)!
        components.queryItems = [URLQueryItem(name: "ctoken", value: ctoken)]
        
        guard let url = components.url else { return [] }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.addValue("https://zenmux.ai", forHTTPHeaderField: "Origin")
        
        let cookieHeader = constructCookieHeader(ctoken: ctoken)
        request.addValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.addValue("https://zenmux.ai/platform/logs", forHTTPHeaderField: "Referer")
        request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        let now = Int(Date().timeIntervalSince1970 * 1000)
        let start = now - (Constants.AccountHistoryRange * 24 * 60 * 60 * 1000)
        
        let body: [String: Any] = [
            "apiKeys": [],
            "startTime": start,
            "stopTime": now,
            "pageNo": page,
            "pageSize": 50, // Use smaller page size for API compatibility
            "modelSlugs": [],
            "providerSlugs": [],
            "finishReasons": []
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return []
        }
        
        let decoder = JSONDecoder()
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        decoder.dateDecodingStrategy = .formatted(isoFormatter)
        
        let historyResponse = try decoder.decode(ZenMuxHistoryResponse.self, from: data)
        return historyResponse.success ? historyResponse.data : []
    }
    
    private func constructCookieHeader(ctoken: String) -> String {
        var cookieParts = ["ctoken=\(ctoken)"]
        if let sid = extractedSessionId { cookieParts.append("sessionId=\(sid)") }
        if let sig = extractedSessionIdSig { cookieParts.append("sessionId.sig=\(sig)") }
        return cookieParts.joined(separator: "; ")
    }
    
    private func formatDateForEvent(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, hh:mm a"
        return formatter.string(from: date)
    }
}

// ZenMux API Response Structures
struct ZenMuxResponse: Codable {
    let success: Bool
    let data: ZenMuxUserData?
}

struct ZenMuxUserData: Codable {
    let userId: String
    let accountId: String
    let displayName: String
    let email: String
    let balance: Double
}

struct ZenMuxCostResponse: Codable {
    let success: Bool
    let data: ZenMuxCostData
}

struct ZenMuxCostData: Codable {
    let totalCost: String
    let inputCost: String
    let outputCost: String
    let otherCost: String
    let requestCounts: String
    let requestAvgCost: String
    let totalTokens: String
    let millionTokenAvgCost: String
}

struct ZenMuxHistoryResponse: Codable {
    let success: Bool
    let data: [ZenMuxHistoryItem]
}

struct ZenMuxHistoryItem: Codable {
    let createdAt: Date
    let modelSlug: String
    let providerSlug: String
    let tokensPrompt: Int
    let tokensCompletion: Int
    let billAmount: String
}
