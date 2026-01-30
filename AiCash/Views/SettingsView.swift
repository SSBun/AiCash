import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case normal = "Normal"
    case providers = "Providers"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .normal: return "gearshape"
        case .providers: return "cpu"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: ProviderViewModel
    @State private var selectedTab: SettingsTab = .normal
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NormalSettingsView()
                .tabItem {
                    Label("Normal", systemImage: "gearshape")
                }
                .tag(SettingsTab.normal)
            
            ProviderSettingsView(viewModel: viewModel)
                .tabItem {
                    Label("Providers", systemImage: "cpu")
                }
                .tag(SettingsTab.providers)
        }
        .frame(width: 600, height: 450)
    }
}

struct NormalSettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false {
        didSet {
            LaunchAtLoginManager.shared.setEnabled(launchAtLogin)
        }
    }
    @AppStorage("refreshInterval") private var refreshInterval = 30
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("General")
                        .font(.system(size: 13, weight: .semibold))
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Launch at login")
                                .font(.system(size: 13, weight: .medium))
                            Text("Automatically start AiCash when you log in.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $launchAtLogin)
                            .toggleStyle(.switch)
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Refresh")
                        .font(.system(size: 13, weight: .semibold))
                    
                    HStack {
                        Text("Refresh Interval (minutes)")
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $refreshInterval) {
                            Text("15").tag(15)
                            Text("30").tag(30)
                            Text("60").tag(60)
                            Text("120").tag(120)
                        }
                        .frame(width: 80)
                    }
                }
                
                Spacer()
            }
            .padding(30)
        }
    }
}

struct ProviderSettingsView: View {
    @ObservedObject var viewModel: ProviderViewModel
    @State private var showingAddProvider = false
    @State private var editingProvider: (any AIProviderProtocol)?
    
    var body: some View {
        VStack(spacing: 0) {
            List {
                Section(header: Text("Active Providers")) {
                    ForEach(viewModel.providers, id: \.id) { provider in
                        HStack {
                            Image(systemName: provider.name == "Cursor" ? "cpu" : "chart.line.uptrend.xyaxis")
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading) {
                                Text(provider.name)
                                    .font(.system(size: 13, weight: .medium))
                                Text(provider.fullName)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            if provider.isLoading {
                                ProgressView()
                                    .scaleEffect(0.5)
                            }
                            
                            Button(action: { editingProvider = provider }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: viewModel.deleteProvider)
                    .onMove(perform: viewModel.moveProvider)
                }
            }
            .listStyle(.inset)
            
            Divider()
            
            HStack {
                Button(action: { showingAddProvider = true }) {
                    Image(systemName: "plus")
                    Text("Add Provider")
                }
                .buttonStyle(.borderless)
                .padding(12)
                
                Spacer()
            }
            .background(Color(NSColor.controlBackgroundColor))
        }
        .sheet(isPresented: $showingAddProvider) {
            AddProviderView(viewModel: viewModel)
        }
        .sheet(item: Binding(
            get: { editingProvider.map { ProviderIdentifiable(provider: $0) } },
            set: { editingProvider = $0?.provider }
        )) { item in
            EditProviderView(viewModel: viewModel, provider: item.provider)
        }
    }
}

struct ProviderIdentifiable: Identifiable {
    let id: UUID
    let provider: any AIProviderProtocol
    
    init(provider: any AIProviderProtocol) {
        self.id = provider.id
        self.provider = provider
    }
}

struct EditProviderView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: ProviderViewModel
    let provider: any AIProviderProtocol
    
    @State private var name: String
    @State private var fullName: String
    @State private var cookieString: String
    @State private var userId: String
    @State private var token: String
    @State private var curlCommand: String
    
    init(viewModel: ProviderViewModel, provider: any AIProviderProtocol) {
        self.viewModel = viewModel
        self.provider = provider
        _name = State(initialValue: provider.name)
        _fullName = State(initialValue: provider.fullName)
        _cookieString = State(initialValue: provider.getCookieString())
        
        if let blt = provider as? BLTProvider {
            _userId = State(initialValue: blt.userId)
            _token = State(initialValue: blt.token)
            _curlCommand = State(initialValue: "")
        } else if let zenmux = provider as? ZenMuxProvider {
            _userId = State(initialValue: "")
            _token = State(initialValue: zenmux.token)
            _curlCommand = State(initialValue: zenmux.curlCommand)
        } else {
            _userId = State(initialValue: "")
            _token = State(initialValue: "")
            _curlCommand = State(initialValue: "")
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit Provider")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
            }
            .padding()
            
            Form {
                Section("Basic Information") {
                    TextField("Display Name", text: $name)
                    TextField("Full Name", text: $fullName)
                }
                
                if provider is CursorProvider {
                    Section("Authentication") {
                        TextEditor(text: $cookieString)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(height: 100)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.2)))
                    }
                } else if let _ = provider as? BLTProvider {
                    Section("Authentication") {
                        TextField("User ID", text: $userId)
                        TextField("Token", text: $token)
                    }
                } else if let _ = provider as? ZenMuxProvider {
                    Section("Authentication") {
                        TextEditor(text: $curlCommand)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(height: 150)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.2)))
                    }
                }
            }
            .formStyle(.grouped)
            
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") {
                    provider.name = name
                    provider.fullName = fullName
                    if let cursor = provider as? CursorProvider {
                        cursor.setCookies(cookieString)
                    } else if let blt = provider as? BLTProvider {
                        blt.userId = userId
                        blt.token = token
                    } else if let zenmux = provider as? ZenMuxProvider {
                        zenmux.token = token
                        zenmux.curlCommand = curlCommand
                    }
                    StorageManager.shared.saveProviders(viewModel.providers)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 400, height: 450)
    }
}


enum ProviderCategory: String, CaseIterable, Identifiable {
    case cursor = "Cursor"
    case blt = "BLT"
    case zenmux = "ZenMux"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .cursor: return "cpu"
        case .blt: return "chart.line.uptrend.xyaxis"
        case .zenmux: return "bolt.shield"
        }
    }
}

struct AddProviderView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: ProviderViewModel
    @State private var selectedCategory: ProviderCategory = .cursor
    
    // Common fields
    @State private var name = ""
    @State private var fullName = ""
    
    // Cursor specific
    @State private var cookieString = ""
    
    // BLT specific
    @State private var userId = ""
    @State private var token = ""
    
    // ZenMux specific
    @State private var curlCommand = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add New Provider")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            // Category Picker
            Picker("Category", selection: $selectedCategory) {
                ForEach(ProviderCategory.allCases) { category in
                    Label(category.rawValue, systemImage: category.icon).tag(category)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 20)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        Text("Basic Information")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        TextField("Display Name (e.g. My Cursor)", text: $name)
                            .textFieldStyle(.roundedBorder)
                        
                        TextField("Full Name (e.g. Cursor AI Pro)", text: $fullName)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    Divider()
                    
                    if selectedCategory == .cursor {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Authentication")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            Text("Please paste your Cursor.com cookies here. You can find them in your browser's Developer Tools (Application -> Cookies).")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            
                            TextEditor(text: $cookieString)
                                .font(.system(size: 11, design: .monospaced))
                                .frame(height: 100)
                                .padding(4)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                            
                            Button(action: {
                                // Placeholder for one-step login logic
                                // In a real app, this could open a webview
                            }) {
                                Label("One-Step Login (Coming Soon)", systemImage: "safari")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(true)
                        }
                    } else if selectedCategory == .blt {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Authentication")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            TextField("User ID", text: $userId)
                                .textFieldStyle(.roundedBorder)
                            
                            TextField("Token", text: $token)
                                .textFieldStyle(.roundedBorder)
                        }
                    } else if selectedCategory == .zenmux {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Authentication")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            Text("Paste the full cURL command for the ZenMux user/info API here.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            
                            TextEditor(text: $curlCommand)
                                .font(.system(size: 11, design: .monospaced))
                                .frame(height: 150)
                                .padding(4)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Footer
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Add Provider") {
                    addProvider()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAddDisabled)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 450, height: 550)
        .onAppear {
            if name.isEmpty {
                updateDefaultNames(for: selectedCategory)
            }
        }
        .onChange(of: selectedCategory) { _, newValue in
            updateDefaultNames(for: newValue)
        }
    }
    
    private func updateDefaultNames(for category: ProviderCategory) {
        switch category {
        case .cursor:
            name = "Cursor"
            fullName = "Cursor AI"
        case .blt:
            name = "BLT"
            fullName = "BLT API"
        case .zenmux:
            name = "ZenMux"
            fullName = "ZenMux AI"
        }
    }
    
    private var isAddDisabled: Bool {
        if name.isEmpty || fullName.isEmpty { return true }
        switch selectedCategory {
        case .cursor:
            return cookieString.isEmpty
        case .blt:
            return userId.isEmpty || token.isEmpty
        case .zenmux:
            return curlCommand.isEmpty
        }
    }
    
    private func addProvider() {
        let provider: any AIProviderProtocol
        switch selectedCategory {
        case .cursor:
            let cursor = CursorProvider()
            cursor.setCookies(cookieString)
            cursor.name = name
            cursor.fullName = fullName
            provider = cursor
        case .blt:
            let blt = BLTProvider()
            blt.userId = userId
            blt.token = token
            blt.name = name
            blt.fullName = fullName
            provider = blt
        case .zenmux:
            let zenmux = ZenMuxProvider()
            zenmux.curlCommand = curlCommand
            zenmux.name = name
            zenmux.fullName = fullName
            provider = zenmux
        }
        
        viewModel.addProvider(provider)
        dismiss()
    }
}


