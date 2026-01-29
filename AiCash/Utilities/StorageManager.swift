import Foundation

class StorageManager {
    static let shared = StorageManager()
    private let providersKey = "saved_providers"
    private let fileManager = FileManager.default
    
    private var storageURL: URL {
        let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportDir = paths[0].appendingPathComponent("AiCash", isDirectory: true)
        
        if !fileManager.fileExists(atPath: appSupportDir.path) {
            try? fileManager.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        }
        
        return appSupportDir.appendingPathComponent("providers.json")
    }
    
    func saveProviders(_ providers: [any AIProviderProtocol]) {
        let codableProviders = providers.compactMap { provider -> ProviderData? in
            if let cursor = provider as? CursorProvider {
                return ProviderData(type: .cursor, name: cursor.name, fullName: cursor.fullName, symbol: cursor.symbol, cookies: cursor.getCookieString())
            } else if let mock = provider as? MockAIProvider {
                return ProviderData(type: .mock, name: mock.name, fullName: mock.fullName, symbol: mock.symbol, cookies: nil)
            }
            return nil
        }
        
        do {
            let data = try JSONEncoder().encode(codableProviders)
            try data.write(to: storageURL)
        } catch {
            print("Failed to save providers: \(error)")
        }
    }
    
    func loadProviders() -> [any AIProviderProtocol] {
        guard fileManager.fileExists(atPath: storageURL.path) else { return [] }
        
        do {
            let data = try Data(contentsOf: storageURL)
            let codableProviders = try JSONDecoder().decode([ProviderData].self, from: data)
            
            return codableProviders.map { data in
                switch data.type {
                case .cursor:
                    let provider = CursorProvider()
                    provider.name = data.name
                    provider.fullName = data.fullName
                    if let cookies = data.cookies {
                        provider.setCookies(cookies)
                    }
                    return provider
                case .mock:
                    return MockAIProvider(
                        name: data.name,
                        symbol: data.symbol,
                        fullName: data.fullName,
                        balance: 0.0,
                        change: 0.0,
                        usageHistory: []
                    )
                }
            }
        } catch {
            print("Failed to load providers: \(error)")
            return []
        }
    }
}

enum ProviderType: String, Codable {
    case cursor
    case mock
}

struct ProviderData: Codable {
    let type: ProviderType
    let name: String
    let fullName: String
    let symbol: String
    let cookies: String?
}
