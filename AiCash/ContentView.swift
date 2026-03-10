import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ProviderViewModel.shared
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var hasRefreshed = false

    var body: some View {
        ZStack {
            DesignSystem.background
                .ignoresSafeArea()

            NavigationSplitView(columnVisibility: $columnVisibility) {
                ProviderListView(viewModel: viewModel)
                    .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 420)
                    .task {
                        if !hasRefreshed && !viewModel.providers.isEmpty {
                            hasRefreshed = true
                            await viewModel.refreshAll()
                        }
                }
            } detail: {
                if let provider = viewModel.selectedProvider {
                    ProviderDetailView(provider: provider)
                        .id(provider.id)
                } else {
                    emptyStateView
                }
            }
            .navigationSplitViewStyle(.balanced)
            .preferredColorScheme(.dark)
        }
        .onChange(of: viewModel.selectedProvider?.id) { _, newValue in
            if newValue != nil {
                columnVisibility = .all
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(DesignSystem.surface)
                    .frame(width: 120, height: 120)

                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(DesignSystem.textMuted)
            }

            VStack(spacing: 8) {
                Text("Select a provider")
                    .font(DesignSystem.displayFont(size: 20, weight: .semibold))
                    .foregroundColor(DesignSystem.textPrimary)

                Text("Choose from the list to view detailed usage")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(DesignSystem.textMuted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
        .frame(width: 1000, height: 700)
}
