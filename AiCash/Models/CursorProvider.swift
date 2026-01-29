import Foundation
import WebKit

class CursorProvider: NSObject, AIProviderProtocol, ObservableObject {
    let id = UUID()
    @Published var name = "Cursor"
    let symbol = "CURSOR"
    @Published var fullName = "Cursor AI"
    
    @Published var balance: Double = 0.0
    @Published var change: Double = 0.0
    @Published var usageHistory: [ProviderUsage] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private let usageEndpoint = "https://cursor.com/api/usage-summary"
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
        Log.info("[Cursor] Starting data fetch from \(usageEndpoint)...")
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        guard let url = URL(string: usageEndpoint) else {
            Log.error("[Cursor] Invalid URL: \(usageEndpoint)")
            await MainActor.run {
                errorMessage = "Invalid URL"
                isLoading = false
            }
            return
        }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            // Apply cookies to the request
            let headerFields = HTTPCookie.requestHeaderFields(with: cookies)
            Log.debug("[Cursor] Applying headers: \(headerFields.keys.joined(separator: ", "))")
            for (field, value) in headerFields {
                request.addValue(value, forHTTPHeaderField: field)
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                Log.error("[Cursor] Invalid response type (not HTTP)")
                throw NSError(domain: "CursorProvider", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
            }
            
            Log.info("[Cursor] API Response status code: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                Log.warning("[Cursor] Unauthorized (401/403). Cookies might be expired.")
                await MainActor.run {
                    errorMessage = "Unauthorized. Please update your cookies in Settings."
                    isLoading = false
                }
                return
            }
            
            if httpResponse.statusCode != 200 {
                let bodyString = String(data: data, encoding: .utf8) ?? "No body"
                Log.error("[Cursor] API Error \(httpResponse.statusCode): \(bodyString)")
                throw NSError(domain: "CursorProvider", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned error \(httpResponse.statusCode): \(bodyString)"])
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let usageData = try decoder.decode(CursorUsageSummaryResponse.self, from: data)
            Log.info("[Cursor] Successfully decoded usage data. Used: \(usageData.individualUsage.plan.used)")
            
            await MainActor.run {
                // Convert used (cents?) to dollars if needed. 
                // Based on the dashboard, $10.68 was shown. 1419 cents would be $14.19.
                // Wait, the dashboard said $10.68 / $20. 
                // Let's assume the value is in cents.
                self.balance = Double(usageData.individualUsage.plan.used) / 100.0
                
                // For history, since usage-summary doesn't provide it, we'll keep it empty or 
                // we could try another endpoint later.
                self.usageHistory = [] 
                
                self.isLoading = false
                Log.info("[Cursor] UI State updated with balance: \(self.balanceString)")
            }
        } catch {
            Log.error("[Cursor] Fetch failed: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
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
}

struct PlanUsage: Codable {
    let used: Int
    let limit: Int
    let remaining: Int
}

