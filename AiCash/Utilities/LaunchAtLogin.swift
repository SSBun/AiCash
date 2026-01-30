import Foundation
import ServiceManagement

class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()
    
    func setEnabled(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                Log.error("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
            }
        }
    }
    
    func isEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }
}
