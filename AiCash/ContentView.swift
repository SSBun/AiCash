import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ProviderViewModel.shared
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            ProviderListView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 250, ideal: 320, max: 400)
        } detail: {
            if let provider = viewModel.selectedProvider {
                ProviderDetailView(provider: provider)
                    .id(provider.id) // Force view refresh when provider changes
            } else {
                VStack {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 64))
                        .foregroundColor(.gray.opacity(0.3))
                        .padding(.bottom, 16)
                    Text("Select a provider to see details")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .preferredColorScheme(.dark)
        .background(.ultraThinMaterial)
        .onChange(of: viewModel.selectedProvider?.id) { _, newValue in
            if newValue != nil {
                columnVisibility = .all
            }
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 1000, height: 700)
}
