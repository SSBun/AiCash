import SwiftUI

struct ProviderRow<Provider: AIProviderProtocol>: View {
    @ObservedObject var provider: Provider
    let isSelected: Bool
    @State private var isHovered = false
    @State private var scale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 16) {
            // Provider icon with dramatic background
            ZStack {
                Circle()
                    .fill(isSelected ? DesignSystem.primary.opacity(0.2) : DesignSystem.surface)
                    .frame(width: 44, height: 44)

                Text(String(provider.symbol.prefix(1)))
                    .font(DesignSystem.displayFont(size: 18, weight: .bold))
                    .foregroundColor(isSelected ? DesignSystem.primary : DesignSystem.textPrimary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(provider.name)
                    .font(DesignSystem.displayFont(size: 15, weight: .semibold))
                    .foregroundColor(DesignSystem.textPrimary)

                Text(provider.symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DesignSystem.textMuted)
            }

            Spacer()

            // Sparkline or mini status
            if provider.usageHistory.count > 1 {
                SparklineView(
                    data: provider.usageHistory.map { $0.amount },
                    color: isSelected ? DesignSystem.primary : DesignSystem.error
                )
                .frame(width: 56, height: 28)
            }

            // Balance display
            VStack(alignment: .trailing, spacing: 3) {
                Text(provider.balanceString)
                    .font(DesignSystem.displayFont(size: 15, weight: .semibold))
                    .foregroundColor(DesignSystem.textPrimary)

                Text(provider.todayUsageString)
                    .font(.system(size: 11, weight: .bold))
                    .frame(minWidth: 56)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(isSelected ? DesignSystem.primary : DesignSystem.error)
                    .cornerRadius(6)
                    .foregroundColor(isSelected ? Color.black : Color.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? DesignSystem.surfaceHover : (isHovered ? DesignSystem.surface : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? DesignSystem.primary.opacity(0.4) : Color.clear, lineWidth: 1)
        )
        .scaleEffect(scale)
        .shadow(color: isSelected ? DesignSystem.primary.opacity(0.15) : Color.clear, radius: 8, x: 0, y: 4)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.2)) {
                isHovered = hovering
                scale = hovering ? 1.01 : 1.0
            }
        }
    }
}

struct ProviderRowWrapper: View {
    let provider: any AIProviderProtocol
    let isSelected: Bool

    var body: some View {
        if let cursor = provider as? CursorProvider {
            ProviderRow(provider: cursor, isSelected: isSelected)
        } else if let blt = provider as? BLTProvider {
            ProviderRow(provider: blt, isSelected: isSelected)
        } else if let zenmux = provider as? ZenMuxProvider {
            ProviderRow(provider: zenmux, isSelected: isSelected)
        } else if let minimax = provider as? MiniMaxProvider {
            MiniMaxRow(provider: minimax, isSelected: isSelected)
        } else {
            Text("Unknown")
        }
    }
}

struct MiniMaxRow: View {
    @ObservedObject var provider: MiniMaxProvider
    let isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 16) {
            // Provider icon
            ZStack {
                Circle()
                    .fill(isSelected ? DesignSystem.primary.opacity(0.2) : DesignSystem.surface)
                    .frame(width: 44, height: 44)

                Text(String(provider.symbol.prefix(1)))
                    .font(DesignSystem.displayFont(size: 18, weight: .bold))
                    .foregroundColor(isSelected ? DesignSystem.primary : DesignSystem.textPrimary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(provider.name)
                    .font(DesignSystem.displayFont(size: 15, weight: .semibold))
                    .foregroundColor(DesignSystem.textPrimary)

                Text(provider.symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DesignSystem.textMuted)
            }

            Spacer()

            // Usage display
            if !provider.modelRemains.isEmpty {
                VStack(alignment: .trailing, spacing: 3) {
                    HStack(spacing: 4) {
                        Text("\(provider.remainingChats)")
                            .font(DesignSystem.displayFont(size: 15, weight: .semibold))
                            .foregroundColor(DesignSystem.textPrimary)
                        Text("left")
                            .font(.system(size: 11))
                            .foregroundColor(DesignSystem.textMuted)
                    }

                    Text("\(Int(provider.modelRemains.first?.remainingPercent ?? 0))%")
                        .font(.system(size: 11, weight: .bold))
                        .frame(minWidth: 56)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(remainingColor)
                        .cornerRadius(6)
                        .foregroundColor(Color.white)
                }
            } else {
                VStack(alignment: .trailing, spacing: 3) {
                    Text("--")
                        .font(DesignSystem.displayFont(size: 15, weight: .semibold))
                        .foregroundColor(DesignSystem.textPrimary)
                    Text("No data")
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.textMuted)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? DesignSystem.surfaceHover : (isHovered ? DesignSystem.surface : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? DesignSystem.primary.opacity(0.4) : Color.clear, lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }

    private var remainingColor: Color {
        let percent = provider.modelRemains.first?.remainingPercent ?? 0
        if percent > 50 {
            return DesignSystem.success
        } else if percent > 20 {
            return DesignSystem.warning
        } else {
            return DesignSystem.error
        }
    }
}

struct ProviderListView: View {
    @ObservedObject var viewModel: ProviderViewModel
    @State private var refreshRotation: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with dramatic typography
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center) {
                    Text("Providers")
                        .font(DesignSystem.displayFont(size: 22, weight: .bold))
                        .foregroundColor(DesignSystem.textPrimary)

                    Spacer()

                    // Refresh button with dramatic hover
                    Button(action: {
                        withAnimation(.easeOut(duration: 0.6)) {
                            refreshRotation += 360
                        }
                        Task {
                            await viewModel.refreshAll()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(DesignSystem.textMuted)
                            .frame(width: 32, height: 32)
                            .background(DesignSystem.surface)
                            .clipShape(Circle())
                            .rotationEffect(.degrees(refreshRotation))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)

            // Divider with accent
            Rectangle()
                .fill(DesignSystem.primary.opacity(0.3))
                .frame(height: 1)
                .padding(.horizontal, 20)

            // List with dramatic spacing
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(viewModel.providers.enumerated()), id: \.element.id) { index, provider in
                        ProviderRowWrapper(
                            provider: provider,
                            isSelected: viewModel.selectedProvider?.id == provider.id
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectedProvider = provider
                        }
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .leading)),
                            removal: .opacity
                        ))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
            }
        }
    }
}

struct SparklineView: View {
    let data: [Double]
    let color: Color
    @State private var animateProgress: Double = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
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
                .stroke(color.opacity(0.2), lineWidth: 1.5)

                // Animated line
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
                .trim(from: 0, to: animateProgress)
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animateProgress = 1
            }
        }
    }
}
