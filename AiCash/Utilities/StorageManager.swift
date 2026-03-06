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
                return ProviderData(type: .cursor, name: cursor.name, fullName: cursor.fullName, symbol: cursor.symbol, cookies: cursor.getCookieString(), userId: nil, token: nil, curlCommand: nil)
            } else if let blt = provider as? BLTProvider {
                return ProviderData(type: .blt, name: blt.name, fullName: blt.fullName, symbol: blt.symbol, cookies: nil, userId: blt.userId, token: blt.token, curlCommand: nil)
            } else if let zenmux = provider as? ZenMuxProvider {
                return ProviderData(type: .zenmux, name: zenmux.name, fullName: zenmux.fullName, symbol: zenmux.symbol, cookies: nil, userId: nil, token: zenmux.token, curlCommand: zenmux.curlCommand)
            } else if let minimax = provider as? MiniMaxProvider {
                return ProviderData(type: .minimax, name: minimax.name, fullName: minimax.fullName, symbol: minimax.symbol, cookies: nil, userId: nil, token: nil, curlCommand: minimax.curlCommand)
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
                case .blt:
                    let provider = BLTProvider()
                    provider.name = data.name
                    provider.fullName = data.fullName
                    provider.userId = data.userId ?? ""
                    provider.token = data.token ?? ""
                    return provider
                case .zenmux:
                    let provider = ZenMuxProvider()
                    provider.name = data.name
                    provider.fullName = data.fullName
                    provider.token = data.token ?? ""
                    provider.curlCommand = data.curlCommand ?? ""
                    return provider
                case .minimax:
                    let provider = MiniMaxProvider()
                    provider.name = data.name
                    provider.fullName = data.fullName
                    provider.curlCommand = data.curlCommand ?? ""
                    return provider
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
    case blt
    case zenmux
    case minimax
}

struct ProviderData: Codable {
    let type: ProviderType
    let name: String
    let fullName: String
    let symbol: String
    let cookies: String?
    let userId: String?
    let token: String?
    let curlCommand: String?
}
