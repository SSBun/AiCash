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
    var change: Double { get }
    var usageHistory: [ProviderUsage] { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    
    func login() async
    func setCookies(_ cookieString: String)
    func getCookieString() -> String
    func fetchData() async
}

extension AIProviderProtocol {
    func setCookies(_ cookieString: String) {}
    func getCookieString() -> String { "" }
}

extension AIProviderProtocol {
    var changeString: String {
        let sign = change >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", change))"
    }
    
    var balanceString: String {
        return String(format: "%.2f", balance)
    }
}

class MockAIProvider: AIProviderProtocol, Hashable {
    let id = UUID()
    @Published var name: String
    @Published var symbol: String
    @Published var fullName: String
    @Published var balance: Double
    @Published var change: Double
    @Published var usageHistory: [ProviderUsage]
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    init(name: String, symbol: String, fullName: String, balance: Double, change: Double, usageHistory: [ProviderUsage]) {
        self.name = name
        self.symbol = symbol
        self.fullName = fullName
        self.balance = balance
        self.change = change
        self.usageHistory = usageHistory
    }
    
    func fetchData() async {
        // Mock fetch
    }
    
    func login() async {
        // Mock login
    }
    
    static func == (lhs: MockAIProvider, rhs: MockAIProvider) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

class ProviderViewModel: ObservableObject {
    static let shared = ProviderViewModel()
    
    @Published var providers: [any AIProviderProtocol] = [] {
        didSet {
            StorageManager.shared.saveProviders(providers)
        }
    }
    @Published var selectedProvider: (any AIProviderProtocol)?
    
    init() {
        self.providers = StorageManager.shared.loadProviders()
        if let first = providers.first {
            self.selectedProvider = first
        }
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
        Log.info("All providers refreshed.")
    }
}


