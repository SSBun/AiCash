import SwiftUI

struct StatusMenuView: View {
    @ObservedObject var viewModel: ProviderViewModel
    @State private var isRefreshing = false
    
    var body: some View {
        VStack(spacing: 0) {
            if isRefreshing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Refreshing...")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(height: 30)
                Divider()
            }
            
            ForEach(viewModel.providers.indices, id: \.self) { index in
                StatusMenuProviderRow(provider: viewModel.providers[index])
                if index < viewModel.providers.count - 1 {
                    Divider()
                }
            }
        }
        .frame(width: 280)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .environment(\.colorScheme, .dark)
        .onAppear {
            isRefreshing = true
            Task { @MainActor in
                await viewModel.refreshAll()
                isRefreshing = false
            }
        }
    }
}

struct StatusMenuProviderRow: View {
    let provider: any AIProviderProtocol
    
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.name)
                    .font(.system(size: 13, weight: .semibold))
                Text(provider.symbol)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(provider.balanceString)
                    .font(.system(size: 13, weight: .medium))
                
                Text(provider.todayUsageString)
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red)
                    .cornerRadius(3)
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
