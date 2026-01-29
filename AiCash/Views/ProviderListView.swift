import SwiftUI

struct ProviderRow<Provider: AIProviderProtocol>: View {
    @ObservedObject var provider: Provider
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text(provider.symbol)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            SparklineView(
                data: provider.usageHistory.map { $0.amount },
                color: provider.change >= 0 ? .red : .green
            )
            .frame(width: 60, height: 32)
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(provider.balanceString)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(provider.changeString)
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 64)
                    .padding(.vertical, 2)
                    .background(provider.change >= 0 ? Color.red : Color.green)
                    .cornerRadius(4)
                    .foregroundColor(.white)
            }
        }
        .frame(height: 48)
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}

struct ProviderRowWrapper: View {
    let provider: any AIProviderProtocol
    let isSelected: Bool
    
    var body: some View {
        if let cursor = provider as? CursorProvider {
            ProviderRow(provider: cursor, isSelected: isSelected)
        } else if let mock = provider as? MockAIProvider {
            ProviderRow(provider: mock, isSelected: isSelected)
        } else {
            Text("Unknown")
        }
    }
}

struct ProviderListView: View {
    @ObservedObject var viewModel: ProviderViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                Text("Search")
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding(8)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
            
            // Header
            HStack {
                Text("My Symbols")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                Spacer()
                Button(action: {
                    Task {
                        await viewModel.refreshAll()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            
            // List
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(viewModel.providers, id: \.id) { provider in
                        ProviderRowWrapper(
                            provider: provider,
                            isSelected: viewModel.selectedProvider?.id == provider.id
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectedProvider = provider
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.top)
        .background(Color(red: 0.1, green: 0.1, blue: 0.1))
    }
}

struct SparklineView: View {
    let data: [Double]
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard data.count > 1 else { return }
                
                let min = data.min() ?? 0
                let max = data.max() ?? 1
                let range = max - min
                
                let stepX = geometry.size.width / CGFloat(data.count - 1)
                let scaleY = geometry.size.height / (range == 0 ? 1 : CGFloat(range))
                
                for index in data.indices {
                    let x = CGFloat(index) * stepX
                    let y = geometry.size.height - (CGFloat(data[index] - min) * scaleY)
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, lineWidth: 1.5)
        }
    }
}
