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

    // ZenMux specific
    @Published var token: String = ""
    @Published var curlCommand: String = ""

    // Credit info
    @Published var accountId: String = ""
    @Published var accountType: String = ""
    @Published var oweFeeSum: Double = 0.0
    @Published var chargeBalance: Double = 0.0
    @Published var discountBalance: Double = 0.0
    @Published var actualFee: Double = 0.0

    // Extracted session info
    private var extractedCtoken: String?
    private var extractedSessionId: String?
    private var extractedSessionIdSig: String?

    private let creditApiEndpoint = "https://zenmux.ai/api/payment/transtion/get_credits"

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
            try await fetchCredits(ctoken: ctoken)
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

    private func fetchCredits(ctoken: String) async throws {
        var components = URLComponents(string: creditApiEndpoint)!
        components.queryItems = [URLQueryItem(name: "ctoken", value: ctoken)]

        guard let url = components.url else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.addValue("en,zh;q=0.9,zh-CN;q=0.8,ja;q=0.7,ru;q=0.6", forHTTPHeaderField: "Accept-Language")
        request.addValue("no-cache", forHTTPHeaderField: "Cache-Control")

        let cookieHeader = constructCookieHeader(ctoken: ctoken)
        request.addValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.addValue("https://zenmux.ai/platform/pay-as-you-go", forHTTPHeaderField: "Referer")
        request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "ZenMuxProvider", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        if httpResponse.statusCode != 200 {
            throw NSError(domain: "ZenMuxProvider", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API returned status \(httpResponse.statusCode)"])
        }

        let decoder = JSONDecoder()
        let creditResponse = try decoder.decode(ZenMuxCreditResponse.self, from: data)

        await MainActor.run {
            if let data = creditResponse.data {
                self.accountId = data.accountId
                self.accountType = data.accountType
                self.oweFeeSum = data.oweFeeSum
                self.balance = data.balance
                self.actualFee = data.actualFee

                // Parse balancesMap
                if let balancesMap = data.balancesMap {
                    self.chargeBalance = balancesMap.charge ?? 0
                    self.discountBalance = balancesMap.discount ?? 0
                }

                // For display: balance shows the actual available credit
                self.balance = data.balance
            }
            Log.info("[ZenMux] Credits fetch successful. Balance: \(self.balance)")
        }
    }

    private func constructCookieHeader(ctoken: String) -> String {
        var cookieParts = ["ctoken=\(ctoken)"]
        if let sid = extractedSessionId { cookieParts.append("sessionId=\(sid)") }
        if let sig = extractedSessionIdSig { cookieParts.append("sessionId.sig=\(sig)") }
        return cookieParts.joined(separator: "; ")
    }
}

// ZenMux API Response Structures
struct ZenMuxCreditResponse: Codable {
    let success: Bool
    let data: ZenMuxCreditData?
}

struct ZenMuxCreditData: Codable {
    let accountId: String
    let accountType: String
    let oweFeeSum: Double
    let balance: Double
    let balancesMap: ZenMuxBalancesMap?
    let actualFee: Double
}

struct ZenMuxBalancesMap: Codable {
    let charge: Double?
    let discount: Double?
}
