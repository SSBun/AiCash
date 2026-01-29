import SwiftUI
import Charts

struct DetailView<Provider: AIProviderProtocol>: View {
    @ObservedObject var provider: Provider
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Information
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(provider.fullName)
                            .font(.system(size: 28, weight: .bold))
                        Text(provider.symbol)
                            .font(.system(size: 18))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    if provider.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .padding(.trailing, 8)
                    }
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(provider.balanceString)
                            .font(.system(size: 32, weight: .bold))
                        
                        HStack(spacing: 4) {
                            Image(systemName: provider.change >= 0 ? "arrow.up.right" : "arrow.down.right")
                            Text(provider.changeString)
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(provider.change >= 0 ? .red : .green)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                if let error = provider.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
                
                Divider()
                    .padding(.horizontal)
                
                // Main Usage Chart
                VStack(alignment: .leading, spacing: 16) {
                    Text("Usage History")
                        .font(.system(size: 20, weight: .bold))
                        .padding(.horizontal)
                    
                    if provider.usageHistory.isEmpty {
                        VStack {
                            Text("No usage data available")
                                .foregroundColor(.gray)
                        }
                        .frame(height: 300)
                        .frame(maxWidth: .infinity)
                    } else {
                        Chart {
                            ForEach(provider.usageHistory) { usage in
                                LineMark(
                                    x: .value("Time", usage.date),
                                    y: .value("Usage", usage.amount)
                                )
                                .foregroundStyle(provider.change >= 0 ? Color.red : Color.green)
                                
                                AreaMark(
                                    x: .value("Time", usage.date),
                                    y: .value("Usage", usage.amount)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            (provider.change >= 0 ? Color.red : Color.green).opacity(0.2),
                                            (provider.change >= 0 ? Color.red : Color.green).opacity(0.0)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            }
                        }
                        .frame(height: 300)
                        .padding(.horizontal)
                    }
                }
                
                // Statistics Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    StatCard(title: "Status", value: provider.isLoading ? "Loading..." : "Active", icon: "bolt.fill")
                    StatCard(title: "Balance", value: "$\(provider.balanceString)", icon: "dollarsign.circle")
                    StatCard(title: "Provider", value: provider.name, icon: "cpu")
                    StatCard(title: "Last Sync", value: "Just now", icon: "clock")
                }
                .padding()
                
                Spacer()
            }
        }
        .background(Color(red: 0.05, green: 0.05, blue: 0.05))
        .onAppear {
            Task {
                await provider.fetchData()
            }
        }
    }
}

struct ProviderDetailView: View {
    let provider: any AIProviderProtocol
    
    var body: some View {
        if let cursor = provider as? CursorProvider {
            DetailView(provider: cursor)
        } else if let mock = provider as? MockAIProvider {
            DetailView(provider: mock)
        } else {
            Text("Unknown provider type")
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}
