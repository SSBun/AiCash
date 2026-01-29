//
//  AiCashApp.swift
//  AiCash
//
//  Created by caishilin on 2026/1/29.
//

import SwiftUI

@main
struct AiCashApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1000, minHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
        
        Settings {
            SettingsView(viewModel: ProviderViewModel.shared)
        }
    }
}
