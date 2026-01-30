import Foundation
import WebKit

class CursorProvider: NSObject, AIProviderProtocol, ObservableObject {
    let id = UUID()
    @Published var name = "Cursor"
    let symbol = "CURSOR"
    @Published var fullName = "Cursor AI"
    
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
    
    private let usageEndpoint = "https://cursor.com/api/usage-summary"
    private let eventsEndpoint = "https://cursor.com/api/dashboard/get-filtered-usage-events"
    private var cookies: [HTTPCookie] = []
    
    func getCookieString() -> String {
        let headerFields = HTTPCookie.requestHeaderFields(with: cookies)
        return headerFields["Cookie"] ?? ""
    }
    
    func setCookies(_ cookieString: String) {
        Log.info("[Cursor] Setting cookies from string...")
        let cookieParts = cookieString.components(separatedBy: ";")
        var newCookies: [HTTPCookie] = []
        for part in cookieParts {
            let pair = part.components(separatedBy: "=")
            if pair.count >= 2 {
                let name = pair[0].trimmingCharacters(in: .whitespaces)
                let value = pair.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespaces)
                if let cookie = HTTPCookie(properties: [
                    .name: name,
                    .value: value,
                    .domain: "cursor.com",
                    .path: "/",
                    .secure: "TRUE"
                ]) {
                    newCookies.append(cookie)
                }
            }
        }
        self.cookies = newCookies
        Log.info("[Cursor] Successfully parsed \(cookies.count) cookies.")
    }
    
    func login() async {
        Log.info("[Cursor] Login method called (manual cookie entry required).")
    }
    
    func fetchData() async {
        Log.info("[Cursor] Starting data fetch...")
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // 1. Fetch Usage Summary
            try await fetchUsageSummary()
            
            // 2. Fetch Usage Events (History)
            try await fetchUsageEvents()
            
            await MainActor.run {
                self.isLoading = false
                Log.info("[Cursor] UI State updated.")
            }
        } catch {
            Log.error("[Cursor] Fetch failed: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func fetchUsageSummary() async throws {
        guard let url = URL(string: usageEndpoint) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let headerFields = HTTPCookie.requestHeaderFields(with: cookies)
        for (field, value) in headerFields {
            request.addValue(value, forHTTPHeaderField: field)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "CursorProvider", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw NSError(domain: "CursorProvider", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unauthorized. Please update cookies."])
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "CursorProvider", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error \(httpResponse.statusCode)"])
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let usageData = try decoder.decode(CursorUsageSummaryResponse.self, from: data)
        
        await MainActor.run {
            self.includedUsage = Double(usageData.individualUsage.plan.used) / 100.0
            self.includedLimit = Double(usageData.individualUsage.plan.limit) / 100.0
            self.onDemandUsage = Double(usageData.individualUsage.onDemand.used) / 100.0
            self.balance = self.includedUsage
        }
    }
    
    private func fetchUsageEvents() async throws {
        guard let url = URL(string: eventsEndpoint) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("https://cursor.com", forHTTPHeaderField: "Origin")
        request.addValue("https://cursor.com/dashboard?tab=usage", forHTTPHeaderField: "Referer")
        
        let headerFields = HTTPCookie.requestHeaderFields(with: cookies)
        for (field, value) in headerFields {
            request.addValue(value, forHTTPHeaderField: field)
        }
        
        // Extract teamId and userId from cookies if possible, or use provided values
        let teamId = 11474358
        let userId = 203422354
        
        let now = Int(Date().timeIntervalSince1970 * 1000)
        let start = now - (30 * 24 * 60 * 60 * 1000) // 30 days ago
        
        let body: [String: Any] = [
            "teamId": teamId,
            "startDate": "\(start)",
            "endDate": "\(now)",
            "userId": userId,
            "page": 1,
            "pageSize": 100
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        Log.info("[Cursor] Fetching events with body: \(body)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return
        }
        
        let decoder = JSONDecoder()
        if let eventsResponse = try? decoder.decode(CursorUsageEventsResponse.self, from: data) {
            await MainActor.run {
                var totalTodayCents = 0.0
                let calendar = Calendar.current
                
                self.usageEvents = eventsResponse.usageEventsDisplay.map { event in
                    let timestampMs = Double(event.timestamp) ?? 0
                    let eventDate = Date(timeIntervalSince1970: timestampMs / 1000.0)
                    
                    let tokenCents = event.tokenUsage?.totalCents ?? 0.0
                    let feeCents = event.cursorTokenFee ?? 0.0
                    let totalCents = tokenCents + feeCents
                    
                    if calendar.isDateInToday(eventDate) {
                        totalTodayCents += totalCents
                    }
                    
                    return UsageEvent(
                        date: self.formatDate(eventDate),
                        user: event.owningUser,
                        type: event.kind,
                        model: event.model,
                        inputTokens: event.tokenUsage?.inputTokens ?? 0,
                        outputTokens: event.tokenUsage?.outputTokens ?? 0,
                        cacheTokens: event.tokenUsage?.cacheReadTokens ?? 0,
                        cost: totalCents
                    )
                }
                
                self.todayUsage = totalTodayCents / 100.0
                
                // Map events to usage history for the sparkline/chart
                self.usageHistory = eventsResponse.usageEventsDisplay.compactMap { event in
                    let timestampMs = Double(event.timestamp) ?? 0
                    let date = Date(timeIntervalSince1970: timestampMs / 1000.0)
                    let totalCents = (event.tokenUsage?.totalCents ?? 0.0) + (event.cursorTokenFee ?? 0.0)
                    return ProviderUsage(date: date, amount: totalCents / 100.0)
                }.sorted(by: { $0.date < $1.date })
                
                Log.info("[Cursor] Successfully loaded \(self.usageEvents.count) events. Today's usage: \(self.todayUsageString)")
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, hh:mm a"
        return formatter.string(from: date)
    }
}

// Updated data structures matching the real Cursor API response
struct CursorUsageSummaryResponse: Codable {
    let billingCycleStart: String
    let billingCycleEnd: String
    let individualUsage: IndividualUsage
}

struct IndividualUsage: Codable {
    let plan: PlanUsage
    let onDemand: OnDemandUsage
}

struct PlanUsage: Codable {
    let used: Int
    let limit: Int
    let remaining: Int
}

struct OnDemandUsage: Codable {
    let used: Int
}

struct CursorUsageEventsResponse: Codable {
    let totalUsageEventsCount: Int
    let usageEventsDisplay: [CursorUsageEvent]
}

struct CursorUsageEvent: Codable {
    let timestamp: String
    let model: String
    let kind: String
    let tokenUsage: CursorTokenUsage?
    let owningUser: String
    let cursorTokenFee: Double?
}

struct CursorTokenUsage: Codable {
    let inputTokens: Int
    let outputTokens: Int
    let cacheReadTokens: Int
    let totalCents: Double
    
    enum CodingKeys: String, CodingKey {
        case inputTokens, outputTokens, cacheReadTokens, totalCents
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        inputTokens = try container.decodeIfPresent(Int.self, forKey: .inputTokens) ?? 0
        outputTokens = try container.decodeIfPresent(Int.self, forKey: .outputTokens) ?? 0
        cacheReadTokens = try container.decodeIfPresent(Int.self, forKey: .cacheReadTokens) ?? 0
        totalCents = try container.decodeIfPresent(Double.self, forKey: .totalCents) ?? 0.0
    }
}
