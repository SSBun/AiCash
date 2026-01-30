import Foundation
import SwiftUI

struct ProviderUsage: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let amount: Double
}

protocol AIProviderProtocol: ObservableObject, Identifiable {
    var id: UUID { get }
    var name: String { get set }
    var symbol: String { get }
    var fullName: String { get set }
    var balance: Double { get }
    var todayUsage: Double { get }
    var usageHistory: [ProviderUsage] { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    
    // New fields for detailed usage
    var includedUsage: Double { get }
    var includedLimit: Double { get }
    var onDemandUsage: Double { get }
    var usageEvents: [UsageEvent] { get }
    
    func login() async
    func setCookies(_ cookieString: String)
    func getCookieString() -> String
    func fetchData() async
}

struct UsageEvent: Identifiable, Hashable {
    let id = UUID()
    let date: String
    let user: String
    let type: String
    let model: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheTokens: Int
    let cost: Double // This will be totalCents + cursorTokenFee
    
    var totalTokens: Int {
        inputTokens + outputTokens + cacheTokens
    }
    
    func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000.0)
        } else {
            return "\(count)"
        }
    }
    
    var inputTokensFormatted: String { formatTokens(inputTokens) }
    var outputTokensFormatted: String { formatTokens(outputTokens) }
    var cacheTokensFormatted: String { formatTokens(cacheTokens) }
    var totalTokensFormatted: String { formatTokens(totalTokens) }
    
    var costFormatted: String {
        return "$\(String(format: "%.5f", cost / 100.0))"
    }
    
    var pricePerMillion: String {
        guard totalTokens > 0 else { return "-" }
        let price = (cost / Double(totalTokens)) * 1_000_000.0
        return "$\(String(format: "%.2f", price / 100.0))"
    }
}

extension AIProviderProtocol {
    var todayUsage: Double { 0.0 }
    var includedUsage: Double { 0.0 }
    var includedLimit: Double { 0.0 }
    var onDemandUsage: Double { 0.0 }
    var usageEvents: [UsageEvent] { [] }
    
    func setCookies(_ cookieString: String) {}
    func getCookieString() -> String { "" }
}

extension AIProviderProtocol {
    var todayUsageString: String {
        return "$\(String(format: "%.2f", todayUsage))"
    }
    
    var balanceString: String {
        return String(format: "%.2f", balance)
    }
}

private let refreshIntervalKey = "refreshInterval"
private let defaultRefreshIntervalMinutes = 30

class ProviderViewModel: ObservableObject {
    static let shared = ProviderViewModel()
    
    @Published var providers: [any AIProviderProtocol] = [] {
        didSet {
            StorageManager.shared.saveProviders(providers)
        }
    }
    @Published var selectedProvider: (any AIProviderProtocol)?
    
    private var refreshTimer: Timer?
    private var lastRefreshTime: Date?
    
    init() {
        self.providers = StorageManager.shared.loadProviders()
        if let first = providers.first {
            self.selectedProvider = first
        }
        
        // Refresh all providers on startup
        Task {
            await refreshAll()
        }
        
        startRefreshTimer()
    }
    
    deinit {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    /// Reads the refresh interval (minutes) from UserDefaults; same key as Settings @AppStorage.
    private func refreshIntervalMinutes() -> Int {
        let value = UserDefaults.standard.object(forKey: refreshIntervalKey) as? Int
        let minutes = value ?? defaultRefreshIntervalMinutes
        return minutes > 0 ? minutes : defaultRefreshIntervalMinutes
    }
    
    /// Starts a timer that checks every minute and triggers refresh when the configured interval has passed.
    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let intervalMinutes = self.refreshIntervalMinutes()
            let intervalSeconds = TimeInterval(intervalMinutes * 60)
            let now = Date()
            if let last = self.lastRefreshTime {
                guard now.timeIntervalSince(last) >= intervalSeconds else { return }
            }
            self.lastRefreshTime = now
            Task { await self.refreshAll() }
        }
        RunLoop.main.add(refreshTimer!, forMode: .common)
    }
    
    func addProvider(_ provider: any AIProviderProtocol) {
        providers.append(provider)
        if selectedProvider == nil {
            selectedProvider = provider
        }
    }
    
    func deleteProvider(at offsets: IndexSet) {
        providers.remove(atOffsets: offsets)
        if let selected = selectedProvider, !providers.contains(where: { $0.id == selected.id }) {
            selectedProvider = providers.first
        }
    }
    
    func moveProvider(from source: IndexSet, to destination: Int) {
        providers.move(fromOffsets: source, toOffset: destination)
    }
    
    func refreshAll() async {
        Log.info("Refreshing all providers (\(providers.count))...")
        for provider in providers {
            await provider.fetchData()
        }
        await MainActor.run {
            lastRefreshTime = Date()
            NotificationCenter.default.post(name: NSNotification.Name("ProvidersUpdated"), object: nil)
        }
        Log.info("All providers refreshed.")
    }
}



