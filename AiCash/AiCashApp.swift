//
//  AiCashApp.swift
//  AiCash
//
//  Created by caishilin on 2026/1/29.
//

import SwiftUI

@main
struct AiCashApp: App {
    @StateObject private var viewModel = ProviderViewModel.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .frame(minWidth: 1000, minHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
        
        Settings {
            SettingsView(viewModel: viewModel)
                .background(.ultraThinMaterial)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController(viewModel: ProviderViewModel.shared)
        
        // Start as accessory app (no dock icon initially)
        NSApp.setActivationPolicy(.accessory)
        
        // Monitor window close events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: nil
        )
    }
    
    @objc private func windowWillClose(_ notification: Notification) {
        // Use a delay to check after the window is actually closed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let hasMainWindow = NSApp.windows.contains { window in
                window.isVisible && window.contentViewController is NSHostingController<ContentView>
            }
            
            if !hasMainWindow {
                print("No main windows visible, hiding from dock")
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // Show in dock when reopening
            NSApp.setActivationPolicy(.regular)
            for window in sender.windows {
                if window.title.isEmpty || window.title == "AiCash" {
                    window.makeKeyAndOrderFront(self)
                    return true
                }
            }
        }
        return true
    }
}
