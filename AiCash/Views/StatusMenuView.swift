import SwiftUI

struct StatusMenuView: View {
    @ObservedObject var viewModel: ProviderViewModel
    @State private var isRefreshing = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("AiCash")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Button(action: {
                    Task {
                        isRefreshing = true
                        await viewModel.refreshAll()
                        isRefreshing = false
                    }
                }) {
                    if isRefreshing {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                    }
                }
                .buttonStyle(.plain)
                .disabled(isRefreshing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.05))

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(viewModel.providers.indices, id: \.self) { index in
                        StatusMenuProviderRow(provider: viewModel.providers[index])
                        if index < viewModel.providers.count - 1 {
                            Divider()
                        }
                    }
                }
            }
            .frame(maxHeight: 350)

            Divider()

            // Footer
            HStack {
                Button(action: {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "macwindow")
                            .font(.system(size: 10))
                        Text("Open Window")
                            .font(.system(size: 11))
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Spacer()

                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "power")
                            .font(.system(size: 10))
                        Text("Quit")
                            .font(.system(size: 11))
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.05))
        }
        .frame(width: 320)
        .background(Color(red: 0.1, green: 0.1, blue: 0.1))
        .onAppear {
            Task { @MainActor in
                await viewModel.refreshAll()
            }
        }
    }
}

struct StatusMenuProviderRow: View {
    let provider: any AIProviderProtocol

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.name)
                        .font(.system(size: 13, weight: .semibold))
                    Text(provider.symbol)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if provider.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }

            // Provider-specific details
            if let zenmux = provider as? ZenMuxProvider {
                ZenMuxStatusRow(provider: zenmux)
            } else if let minimax = provider as? MiniMaxProvider {
                MiniMaxStatusRow(provider: minimax)
            } else {
                // Default row for Cursor, BLT, etc.
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Balance")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("$\(provider.balanceString)")
                            .font(.system(size: 14, weight: .medium))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Today")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text(provider.todayUsageString)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

struct ZenMuxStatusRow: View {
    @ObservedObject var provider: ZenMuxProvider

    var body: some View {
        VStack(spacing: 8) {
            // Wallet balance
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Wallet")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("$\(String(format: "%.2f", provider.balance))")
                        .font(.system(size: 14, weight: .medium))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Today")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("$\(String(format: "%.6f", provider.todayUsage))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red)
                }
            }

            // Balance breakdown
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("Charge")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text("$\(String(format: "%.2f", provider.chargeBalance))")
                        .font(.system(size: 10, weight: .medium))
                }

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                    Text("Discount")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text("$\(String(format: "%.2f", provider.discountBalance))")
                        .font(.system(size: 10, weight: .medium))
                }
            }
        }
    }
}

struct MiniMaxStatusRow: View {
    @ObservedObject var provider: MiniMaxProvider

    var body: some View {
        VStack(spacing: 8) {
            // Remaining chats
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remaining")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("\(provider.remainingChats) chats")
                        .font(.system(size: 14, weight: .medium))
                }

                Spacer()

                if let first = provider.modelRemains.first {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Used")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("\(provider.totalChats - provider.remainingChats)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.red)
                    }
                }
            }

            // Progress bar
            if let first = provider.modelRemains.first {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(remainingColor(percent: first.remainingPercent))
                            .frame(width: geo.size.width * CGFloat(first.remainingPercent / 100), height: 6)
                    }
                }
                .frame(height: 6)

                // Model list
                ForEach(provider.modelRemains.prefix(3)) { model in
                    HStack {
                        Text(model.modelName)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(model.remainingPercent))%")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(remainingColor(percent: model.remainingPercent))
                    }
                }
            }
        }
    }

    private func remainingColor(percent: Double) -> Color {
        if percent > 50 {
            return .green
        } else if percent > 20 {
            return .orange
        } else {
            return .red
        }
    }
}
