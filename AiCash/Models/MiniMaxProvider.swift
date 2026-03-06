import Foundation
import SwiftUI

class MiniMaxProvider: NSObject, AIProviderProtocol, ObservableObject {
    let id = UUID()
    @Published var name = "MiniMax"
    let symbol = "MM"
    @Published var fullName = "MiniMax AI"

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

    // MiniMax specific - remaining chat count
    @Published var remainingChats: Int = 0
    @Published var totalChats: Int = 0
    @Published var modelRemains: [ModelRemain] = []

    // Time window info
    @Published var currentPeriodStart: Date?
    @Published var currentPeriodEnd: Date?

    @Published var curlCommand: String = ""

    private let apiEndpoint = "https://www.minimaxi.com/v1/api/openplatform/coding_plan/remains"

    // Override balanceString to show chat count instead of currency
    var balanceString: String {
        return "\(remainingChats)"
    }

    var todayUsageString: String {
        return "\(totalChats - remainingChats) used"
    }

    func login() async {
        Log.info("[MiniMax] Login method called.")
    }

    func setCookies(_ cookieString: String) {
        // Not used for MiniMax
    }

    func getCookieString() -> String {
        return curlCommand
    }

    private func extractCookiesFromCurl() -> String? {
        Log.info("[MiniMax] Extracting cookies from cURL command...")

        var cookieString = ""

        // Look for -b 'cookies' or -b "cookies"
        if let range = curlCommand.range(of: "-b\\s+['\"]([^'\"]+)['\"]", options: .regularExpression) {
            let match = String(curlCommand[range])
            if let startQuote = match.firstIndex(of: "'"), let endQuote = match.lastIndex(of: "'") {
                let start = match.index(after: startQuote)
                cookieString = String(match[start..<endQuote])
            } else if let startQuote = match.firstIndex(of: "\""), let endQuote = match.lastIndex(of: "\"") {
                let start = match.index(after: startQuote)
                cookieString = String(match[start..<endQuote])
            }
        }

        // Also check for -b without quotes
        if cookieString.isEmpty {
            if let range = curlCommand.range(of: "-b\\s+([^\\s]+)", options: .regularExpression) {
                let match = String(curlCommand[range])
                let parts = match.components(separatedBy: " ")
                if parts.count >= 2 {
                    cookieString = parts[1]
                }
            }
        }

        if !cookieString.isEmpty {
            Log.info("[MiniMax] Extracted cookies successfully")
        }

        return cookieString.isEmpty ? nil : cookieString
    }

    private func extractGroupId() -> String? {
        if let range = curlCommand.range(of: "GroupId=([^&'\"\\s]+)", options: .regularExpression) {
            let match = String(curlCommand[range])
            return match.replacingOccurrences(of: "GroupId=", with: "")
        }
        return nil
    }

    func fetchData() async {
        guard !curlCommand.isEmpty else {
            await MainActor.run {
                self.errorMessage = "cURL command is required"
            }
            return
        }

        Log.info("[MiniMax] Starting data fetch...")
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        guard let cookies = extractCookiesFromCurl() else {
            await MainActor.run {
                self.errorMessage = "Could not extract cookies from cURL command"
                self.isLoading = false
            }
            return
        }

        guard let groupId = extractGroupId() else {
            await MainActor.run {
                self.errorMessage = "Could not find GroupId in cURL command"
                self.isLoading = false
            }
            return
        }

        do {
            try await fetchRemainingChats(cookies: cookies, groupId: groupId)
            await MainActor.run {
                self.isLoading = false
            }
        } catch {
            Log.error("[MiniMax] Fetch failed: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func fetchRemainingChats(cookies: String, groupId: String) async throws {
        var components = URLComponents(string: apiEndpoint)!
        components.queryItems = [URLQueryItem(name: "GroupId", value: groupId)]

        guard let url = components.url else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.addValue("en,zh;q=0.9,zh-CN;q=0.8,ja;q=0.7,ru;q=0.6", forHTTPHeaderField: "Accept-Language")
        request.addValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.addValue(cookies, forHTTPHeaderField: "Cookie")
        request.addValue("https://platform.minimaxi.com/", forHTTPHeaderField: "Referer")
        request.addValue("platform.minimaxi.com", forHTTPHeaderField: "Origin")
        request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "MiniMaxProvider", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        if httpResponse.statusCode != 200 {
            throw NSError(domain: "MiniMaxProvider", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API returned status \(httpResponse.statusCode)"])
        }

        let decoder = JSONDecoder()
        let miniMaxResponse = try decoder.decode(MiniMaxResponse.self, from: data)

        await MainActor.run {
            if let modelRemains = miniMaxResponse.modelRemains, !modelRemains.isEmpty {
                self.modelRemains = modelRemains
                // Use the first model's data for display (they all share the same time window)
                if let first = modelRemains.first {
                    self.totalChats = first.currentIntervalTotalCount
                    // current_interval_usage_count is the remaining count available to use
                    self.remainingChats = first.currentIntervalUsageCount
                    self.balance = Double(self.remainingChats)

                    // Set time window (timestamps are in milliseconds)
                    self.currentPeriodStart = Date(timeIntervalSince1970: Double(first.startTime) / 1000.0)
                    self.currentPeriodEnd = Date(timeIntervalSince1970: Double(first.endTime) / 1000.0)
                }
            }
            Log.info("[MiniMax] Remaining chats: \(self.remainingChats) / \(self.totalChats)")
        }
    }
}

// MiniMax API Response Structures
struct MiniMaxResponse: Codable {
    let modelRemains: [ModelRemain]?
    let baseResp: BaseResp?

    enum CodingKeys: String, CodingKey {
        case modelRemains = "model_remains"
        case baseResp = "base_resp"
    }
}

struct ModelRemain: Codable, Identifiable {
    let startTime: Int64
    let endTime: Int64
    let remainsTime: Int64
    let currentIntervalTotalCount: Int
    let currentIntervalUsageCount: Int
    let modelName: String

    enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
        case remainsTime = "remains_time"
        case currentIntervalTotalCount = "current_interval_total_count"
        case currentIntervalUsageCount = "current_interval_usage_count"
        case modelName = "model_name"
    }

    var id: String { modelName }

    // currentIntervalUsageCount is the remaining count available to use
    var remainingCount: Int {
        currentIntervalUsageCount
    }

    var usedCount: Int {
        currentIntervalTotalCount - currentIntervalUsageCount
    }

    var remainingPercent: Double {
        guard currentIntervalTotalCount > 0 else { return 0 }
        return Double(currentIntervalUsageCount) / Double(currentIntervalTotalCount) * 100
    }

    var usedPercent: Double {
        guard currentIntervalTotalCount > 0 else { return 0 }
        return Double(usedCount) / Double(currentIntervalTotalCount) * 100
    }

    var periodStartDate: Date {
        Date(timeIntervalSince1970: Double(startTime) / 1000.0)
    }

    var periodEndDate: Date {
        Date(timeIntervalSince1970: Double(endTime) / 1000.0)
    }

    var timeWindowString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        return "\(formatter.string(from: periodStartDate)) - \(formatter.string(from: periodEndDate))"
    }

    var nextRefreshString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        return formatter.string(from: periodEndDate)
    }
}

struct BaseResp: Codable {
    let statusCode: Int
    let statusMsg: String

    enum CodingKeys: String, CodingKey {
        case statusCode = "status_code"
        case statusMsg = "status_msg"
    }
}
