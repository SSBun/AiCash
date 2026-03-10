import SwiftUI
import Charts

// MARK: - DailyCost Model

struct DailyCost: Identifiable {
    let id = UUID()
    let date: Date
    let amount: Double
}

struct DetailView<Provider: AIProviderProtocol>: View {
    @ObservedObject var provider: Provider
    @State private var refreshRotation: Double = 0
    @State private var contentOpacity: Double = 0

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 32) {
                headerSection

                if let error = provider.errorMessage {
                    errorBanner(error)
                }

                // Dramatic accent divider
                accentDivider

                usageOverviewSection

                statisticsGridSection

                if !provider.usageEvents.isEmpty {
                    usageEventsSection
                }

                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(DesignSystem.error)

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(DesignSystem.error.opacity(0.9))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.error.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DesignSystem.error.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    private var accentDivider: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(DesignSystem.primary)
                .frame(width: 40, height: 3)
                .cornerRadius(1.5)

            Rectangle()
                .fill(DesignSystem.primary.opacity(0.5))
                .frame(height: 1)

            Rectangle()
                .fill(DesignSystem.primary.opacity(0.2))
                .frame(height: 1)
        }
        .padding(.horizontal, 20)
    }

    private var headerSection: some View {
        HStack(alignment: .bottom, spacing: 0) {
            // Provider info with dramatic typography
            VStack(alignment: .leading, spacing: 6) {
                Text(provider.fullName)
                    .font(DesignSystem.displayFont(size: 32, weight: .bold))
                    .foregroundColor(DesignSystem.textPrimary)

                Text(provider.symbol)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(DesignSystem.textMuted)
            }

            Spacer()

            // Balance display with gold accent
            VStack(alignment: .trailing, spacing: 6) {
                HStack(alignment: .bottom, spacing: 4) {
                    Text(provider.balanceString)
                        .font(DesignSystem.displayFont(size: 36, weight: .bold))
                        .foregroundColor(DesignSystem.primary)

                    Text("USD")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignSystem.textMuted)
                        .padding(.bottom, 6)
                }

                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .bold))
                    Text(provider.todayUsageString)
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DesignSystem.error)
            }

            // Refresh button
            Button(action: {
                withAnimation(.easeOut(duration: 0.6)) {
                    refreshRotation += 360
                }
                Task {
                    await provider.fetchData()
                }
            }) {
                Group {
                    if provider.isLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(DesignSystem.textMuted)
                    }
                }
                .frame(width: 36, height: 36)
                .background(DesignSystem.surface)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(DesignSystem.surfaceHover, lineWidth: 1)
                )
                .rotationEffect(.degrees(refreshRotation))
            }
            .buttonStyle(.plain)
            .padding(.leading, 16)
            .help("Refresh data")
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
    }

    private var usageOverviewSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section header with dramatic styling
            HStack {
                Text("Usage Overview")
                    .font(DesignSystem.displayFont(size: 20, weight: .bold))
                    .foregroundColor(DesignSystem.textPrimary)

                Spacer()

                // Subtle accent indicator
                Circle()
                    .fill(DesignSystem.primary)
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal, 24)

            // Usage cards with dramatic styling
            if !(provider is BLTProvider) {
                HStack(spacing: 16) {
                    UsageCard(
                        title: "Included Usage",
                        value: "$\(String(format: "%.2f", provider.includedUsage))",
                        limit: "$\(String(format: "%.0f", provider.includedLimit))",
                        progress: provider.includedLimit > 0 ? provider.includedUsage / provider.includedLimit : 0,
                        accentColor: DesignSystem.primary
                    )

                    UsageCard(
                        title: "On-Demand Usage",
                        value: "$\(String(format: "%.2f", provider.onDemandUsage))",
                        limit: "Unlimited",
                        progress: 0,
                        isUnlimited: true,
                        accentColor: DesignSystem.success
                    )
                }
                .padding(.horizontal, 24)
            } else {
                HStack(spacing: 16) {
                    UsageCard(
                        title: "Used Quota",
                        value: "$\(String(format: "%.2f", provider.includedUsage))",
                        limit: "Total",
                        progress: 0,
                        isUnlimited: true,
                        accentColor: DesignSystem.warning
                    )

                    UsageCard(
                        title: "Remaining Quota",
                        value: "$\(String(format: "%.2f", provider.balance))",
                        limit: "Current",
                        progress: 0,
                        isUnlimited: true,
                        accentColor: DesignSystem.success
                    )
                }
                .padding(.horizontal, 24)
            }

            // Charts
            if !provider.usageHistory.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Usage Trend")
                        .font(DesignSystem.displayFont(size: 16, weight: .semibold))
                        .foregroundColor(DesignSystem.textSecondary)
                        .padding(.horizontal, 24)

                    usageChart
                        .padding(.horizontal, 24)
                }
                .padding(.top, 8)
            }

            if !dailyCostData.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Daily Cost")
                        .font(DesignSystem.displayFont(size: 16, weight: .semibold))
                        .foregroundColor(DesignSystem.textSecondary)
                        .padding(.horizontal, 24)

                    dailyCostChart
                        .padding(.horizontal, 24)
                }
                .padding(.top, 8)
            }
        }
    }

    /// Aggregates usage history by calendar day for the bar chart.
    private var dailyCostData: [DailyCost] {
        let calendar = Calendar.current
        var byDay: [Date: Double] = [:]
        for usage in provider.usageHistory {
            let day = calendar.startOfDay(for: usage.date)
            byDay[day, default: 0] += usage.amount
        }
        return byDay.sorted(by: { $0.key < $1.key }).map { DailyCost(date: $0.key, amount: $0.value) }
    }

    private var dailyCostChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart(dailyCostData) { item in
                BarMark(
                    x: .value("Date", item.date),
                    y: .value("Cost", item.amount),
                    width: .fixed(32)
                )
                .foregroundStyle(DesignSystem.primary.opacity(0.7))
                .cornerRadius(4)
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic) { value in
                    AxisGridLine()
                        .foregroundStyle(DesignSystem.surfaceHover)
                    AxisValueLabel()
                        .foregroundStyle(DesignSystem.textMuted)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 1)) { _ in
                    AxisGridLine()
                        .foregroundStyle(DesignSystem.surfaceHover)
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .foregroundStyle(DesignSystem.textMuted)
                }
            }
            .frame(height: 180)
        }
        .padding(20)
        .background(DesignSystem.surface)
        .cornerRadius(16)
    }

    private var usageChart: some View {
        Chart {
            ForEach(provider.usageHistory) { usage in
                LineMark(
                    x: .value("Time", usage.date),
                    y: .value("Usage", usage.amount)
                )
                .foregroundStyle(DesignSystem.error)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

                AreaMark(
                    x: .value("Time", usage.date),
                    y: .value("Usage", usage.amount)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            DesignSystem.error.opacity(0.3),
                            DesignSystem.error.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .frame(height: 180)
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine()
                    .foregroundStyle(DesignSystem.surfaceHover)
                AxisValueLabel()
                    .foregroundStyle(DesignSystem.textMuted)
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine()
                    .foregroundStyle(DesignSystem.surfaceHover)
                AxisValueLabel()
                    .foregroundStyle(DesignSystem.textMuted)
            }
        }
        .padding(20)
        .background(DesignSystem.surface)
        .cornerRadius(16)
    }

    private var usageEventsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                Text("Recent Events")
                    .font(DesignSystem.displayFont(size: 20, weight: .bold))
                    .foregroundColor(DesignSystem.textPrimary)

                Spacer()

                Text("\(provider.usageEvents.count) events")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignSystem.textMuted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(DesignSystem.surface)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)

            // Events table
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Date").frame(width: 90, alignment: .leading)
                    Text("Model").frame(maxWidth: .infinity, alignment: .leading)
                    Text("In").frame(width: 50, alignment: .trailing)
                    if !(provider is BLTProvider) {
                        Text("Out").frame(width: 50, alignment: .trailing)
                        Text("Cache").frame(width: 50, alignment: .trailing)
                    }
                    Text("Total").frame(width: 60, alignment: .trailing)
                    Text("Cost").frame(width: 70, alignment: .trailing)
                    if !(provider is BLTProvider) {
                        Text("$/1M").frame(width: 50, alignment: .trailing)
                    }
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(DesignSystem.textMuted)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(DesignSystem.surfaceHover)

                ForEach(Array(provider.usageEvents.enumerated()), id: \.element.id) { index, event in
                    if index > 0 {
                        Divider()
                            .background(DesignSystem.surfaceHover)
                    }

                    HStack {
                        Text(event.date).frame(width: 90, alignment: .leading)
                        Text(event.model)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(event.inputTokensFormatted).frame(width: 50, alignment: .trailing)
                            .foregroundColor(DesignSystem.textSecondary)
                        if !(provider is BLTProvider) {
                            Text(event.outputTokensFormatted).frame(width: 50, alignment: .trailing)
                                .foregroundColor(DesignSystem.textSecondary)
                            Text(event.cacheTokensFormatted).frame(width: 50, alignment: .trailing)
                                .foregroundColor(DesignSystem.textMuted)
                        }
                        Text(event.totalTokensFormatted).frame(width: 60, alignment: .trailing)
                            .font(.system(size: 11, weight: .semibold))
                        Text(event.costFormatted).frame(width: 70, alignment: .trailing)
                            .foregroundColor(DesignSystem.primary)
                        if !(provider is BLTProvider) {
                            Text(event.pricePerMillion).frame(width: 50, alignment: .trailing)
                                .foregroundColor(DesignSystem.textMuted)
                        }
                    }
                    .font(.system(size: 11))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(index % 2 == 0 ? Color.clear : DesignSystem.surface.opacity(0.3))
                }
            }
            .background(DesignSystem.backgroundElevated)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(DesignSystem.surfaceHover, lineWidth: 1)
            )
            .padding(.horizontal, 24)
        }
    }

    private var statisticsGridSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(title: "Status", value: provider.isLoading ? "Loading..." : "Active", icon: "bolt.fill", iconColor: DesignSystem.warning)
            StatCard(title: "Balance", value: "$\(provider.balanceString)", icon: "dollarsign.circle", iconColor: DesignSystem.success)
            StatCard(title: "Provider", value: provider.name, icon: "cpu", iconColor: DesignSystem.primary)
            StatCard(title: "Last Sync", value: "Just now", icon: "clock", iconColor: DesignSystem.textMuted)
        }
        .padding(.horizontal, 24)
    }
}

struct ProviderDetailView: View {
    let provider: any AIProviderProtocol

    var body: some View {
        if let cursor = provider as? CursorProvider {
            DetailView(provider: cursor)
        } else if let blt = provider as? BLTProvider {
            DetailView(provider: blt)
        } else if let zenmux = provider as? ZenMuxProvider {
            ZenMuxDetailView(provider: zenmux)
        } else if let minimax = provider as? MiniMaxProvider {
            MiniMaxDetailView(provider: minimax)
        } else {
            Text("Unknown provider type")
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let iconColor: Color
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DesignSystem.textMuted)

                Spacer()
            }

            Text(value)
                .font(DesignSystem.displayFont(size: 22, weight: .bold))
                .foregroundColor(DesignSystem.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isHovered ? DesignSystem.surfaceHover : DesignSystem.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(DesignSystem.surfaceHover, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

struct UsageCard: View {
    let title: String
    let value: String
    let limit: String
    let progress: Double
    var isUnlimited: Bool = false
    let accentColor: Color
    @State private var animatedProgress: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Title with accent indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(accentColor)
                    .frame(width: 6, height: 6)

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DesignSystem.textSecondary)
            }

            // Value display
            HStack(alignment: .bottom, spacing: 6) {
                Text(value)
                    .font(DesignSystem.displayFont(size: 28, weight: .bold))
                    .foregroundColor(DesignSystem.textPrimary)

                Text("/ \(limit)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignSystem.textMuted)
                    .padding(.bottom, 4)
            }

            // Progress bar
            if !isUnlimited {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Track
                        RoundedRectangle(cornerRadius: 4)
                            .fill(DesignSystem.surfaceHover)

                        // Progress
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [accentColor, accentColor.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(min(animatedProgress, 1.0)))
                            .shadow(color: accentColor.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                }
                .frame(height: 8)
            } else {
                // Divider for unlimited
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(DesignSystem.surfaceHover)
                        .frame(height: 1)

                    Text("UNLIMITED")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(DesignSystem.textMuted)

                    Rectangle()
                        .fill(DesignSystem.surfaceHover)
                        .frame(height: 1)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(DesignSystem.surfaceHover, lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animatedProgress = progress
            }
        }
    }
}

// MARK: - ZenMux Detail View

struct ZenMuxDetailView: View {
    @ObservedObject var provider: ZenMuxProvider
    @State private var contentOpacity: Double = 0

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 32) {
                headerSection

                if let error = provider.errorMessage {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(DesignSystem.error)
                        Text(error)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(DesignSystem.error.opacity(0.9))
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignSystem.error.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(DesignSystem.error.opacity(0.3), lineWidth: 1))
                    .padding(.horizontal)
                }

                accentDivider

                usageOverviewSection

                walletSection

                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                contentOpacity = 1
            }
        }
    }

    private var accentDivider: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(DesignSystem.primary)
                .frame(width: 40, height: 3)
                .cornerRadius(1.5)
            Rectangle()
                .fill(DesignSystem.primary.opacity(0.5))
                .frame(height: 1)
            Rectangle()
                .fill(DesignSystem.primary.opacity(0.2))
                .frame(height: 1)
        }
        .padding(.horizontal, 24)
    }

    private var headerSection: some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(provider.fullName)
                    .font(DesignSystem.displayFont(size: 32, weight: .bold))
                    .foregroundColor(DesignSystem.textPrimary)
                Text(provider.symbol)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(DesignSystem.textMuted)
            }

            Spacer()

            if provider.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button(action: {
                    Task {
                        await provider.fetchData()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(DesignSystem.textMuted)
                        .frame(width: 36, height: 36)
                        .background(DesignSystem.surface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
    }

    private var usageOverviewSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Today's Usage")
                    .font(DesignSystem.displayFont(size: 20, weight: .bold))
                    .foregroundColor(DesignSystem.textPrimary)
                Spacer()
                Circle()
                    .fill(DesignSystem.primary)
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal, 24)

            HStack(spacing: 16) {
                UsageCard(
                    title: "Total Cost",
                    value: "$\(String(format: "%.6f", provider.todayUsage))",
                    limit: "Today",
                    progress: 0,
                    isUnlimited: true,
                    accentColor: DesignSystem.primary
                )

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Input")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DesignSystem.textMuted)
                        Spacer()
                        Text("$\(String(format: "%.6f", provider.todayInputCost))")
                            .font(DesignSystem.displayFont(size: 14, weight: .semibold))
                            .foregroundColor(DesignSystem.textPrimary)
                    }

                    HStack {
                        Text("Output")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DesignSystem.textMuted)
                        Spacer()
                        Text("$\(String(format: "%.6f", provider.todayOutputCost))")
                            .font(DesignSystem.displayFont(size: 14, weight: .semibold))
                            .foregroundColor(DesignSystem.textPrimary)
                    }

                    HStack {
                        Text("Requests")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DesignSystem.textMuted)
                        Spacer()
                        Text("\(provider.todayRequestCount)")
                            .font(DesignSystem.displayFont(size: 14, weight: .semibold))
                            .foregroundColor(DesignSystem.primary)
                    }
                }
                .padding(18)
                .background(DesignSystem.surface)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(DesignSystem.surfaceHover, lineWidth: 1))
            }
            .padding(.horizontal, 24)
        }
    }

    private var walletSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Wallet Balance")
                    .font(DesignSystem.displayFont(size: 20, weight: .bold))
                    .foregroundColor(DesignSystem.textPrimary)
                Spacer()
                Circle()
                    .fill(DesignSystem.success)
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal, 24)

            HStack(spacing: 16) {
                UsageCard(
                    title: "Total Balance",
                    value: "$\(String(format: "%.2f", provider.balance))",
                    limit: "Available",
                    progress: 0,
                    isUnlimited: true,
                    accentColor: DesignSystem.success
                )

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Charge")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DesignSystem.textMuted)
                        Spacer()
                        Text("$\(String(format: "%.2f", provider.chargeBalance))")
                            .font(DesignSystem.displayFont(size: 14, weight: .semibold))
                            .foregroundColor(DesignSystem.success)
                    }

                    HStack {
                        Text("Discount")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DesignSystem.textMuted)
                        Spacer()
                        Text("$\(String(format: "%.2f", provider.discountBalance))")
                            .font(DesignSystem.displayFont(size: 14, weight: .semibold))
                            .foregroundColor(DesignSystem.warning)
                    }

                    Divider()
                        .background(DesignSystem.surfaceHover)

                    HStack {
                        Text("Owe")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DesignSystem.textMuted)
                        Spacer()
                        Text("$\(String(format: "%.2f", provider.oweFeeSum))")
                            .font(DesignSystem.displayFont(size: 14, weight: .semibold))
                            .foregroundColor(provider.oweFeeSum > 0 ? DesignSystem.error : DesignSystem.textPrimary)
                    }
                }
                .padding(18)
                .background(DesignSystem.surface)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(DesignSystem.surfaceHover, lineWidth: 1))
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - MiniMax Detail View

struct MiniMaxDetailView: View {
    @ObservedObject var provider: MiniMaxProvider
    @State private var contentOpacity: Double = 0

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 32) {
                headerSection

                if let error = provider.errorMessage {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(DesignSystem.error)
                        Text(error)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(DesignSystem.error.opacity(0.9))
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignSystem.error.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(DesignSystem.error.opacity(0.3), lineWidth: 1))
                    .padding(.horizontal)
                }

                accentDivider

                subscriptionSection

                timeWindowSection

                modelListSection

                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                contentOpacity = 1
            }
        }
    }

    private var accentDivider: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(DesignSystem.primary)
                .frame(width: 40, height: 3)
                .cornerRadius(1.5)
            Rectangle()
                .fill(DesignSystem.primary.opacity(0.5))
                .frame(height: 1)
            Rectangle()
                .fill(DesignSystem.primary.opacity(0.2))
                .frame(height: 1)
        }
        .padding(.horizontal, 24)
    }

    private var headerSection: some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(provider.fullName)
                    .font(DesignSystem.displayFont(size: 32, weight: .bold))
                    .foregroundColor(DesignSystem.textPrimary)
                Text(provider.symbol)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(DesignSystem.textMuted)
            }

            Spacer()

            if provider.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button(action: {
                    Task {
                        await provider.fetchData()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(DesignSystem.textMuted)
                        .frame(width: 36, height: 36)
                        .background(DesignSystem.surface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
    }

    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Subscription")
                    .font(DesignSystem.displayFont(size: 20, weight: .bold))
                    .foregroundColor(DesignSystem.textPrimary)
                Spacer()
                Circle()
                    .fill(DesignSystem.primary)
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal, 24)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Current Plan")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignSystem.textMuted)
                    Text(provider.currentSubscriptionTitle.isEmpty ? "--" : provider.currentSubscriptionTitle)
                        .font(DesignSystem.displayFont(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.textPrimary)
                }

                Spacer()

                if let combo = provider.currentComboCard {
                    VStack(alignment: .trailing, spacing: 6) {
                        Text("Price")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DesignSystem.textMuted)
                        Text(combo.priceString)
                            .font(DesignSystem.displayFont(size: 14, weight: .semibold))
                            .foregroundColor(DesignSystem.success)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        Text("Cycle")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DesignSystem.textMuted)
                        Text(combo.cycleString)
                            .font(DesignSystem.displayFont(size: 14, weight: .semibold))
                            .foregroundColor(DesignSystem.textPrimary)
                    }
                }

                VStack(alignment: .trailing, spacing: 6) {
                    Text("Expires")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignSystem.textMuted)
                    Text(provider.currentSubscriptionEndDate.isEmpty ? "--" : provider.currentSubscriptionEndDate)
                        .font(DesignSystem.displayFont(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.warning)
                }
            }
            .padding(18)
            .background(DesignSystem.surface)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(DesignSystem.surfaceHover, lineWidth: 1))
            .padding(.horizontal, 24)
        }
    }

    private var timeWindowSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Current Period")
                    .font(DesignSystem.displayFont(size: 20, weight: .bold))
                    .foregroundColor(DesignSystem.textPrimary)
                Spacer()
                Circle()
                    .fill(DesignSystem.warning)
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal, 24)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Time Window")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignSystem.textMuted)
                    if let start = provider.currentPeriodStart, let end = provider.currentPeriodEnd {
                        Text(formatDateRange(start: start, end: end))
                            .font(DesignSystem.displayFont(size: 14, weight: .semibold))
                            .foregroundColor(DesignSystem.textPrimary)
                    } else {
                        Text("--")
                            .font(DesignSystem.displayFont(size: 14, weight: .medium))
                            .foregroundColor(DesignSystem.textMuted)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text("Next Refresh")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignSystem.textMuted)
                    if let end = provider.currentPeriodEnd {
                        Text(formatDate(end))
                            .font(DesignSystem.displayFont(size: 14, weight: .semibold))
                            .foregroundColor(DesignSystem.warning)
                    } else {
                        Text("--")
                            .font(DesignSystem.displayFont(size: 14, weight: .medium))
                            .foregroundColor(DesignSystem.textMuted)
                    }
                }
            }
            .padding(18)
            .background(DesignSystem.surface)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(DesignSystem.surfaceHover, lineWidth: 1))
            .padding(.horizontal, 24)
        }
    }

    private var modelListSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Models")
                    .font(DesignSystem.displayFont(size: 20, weight: .bold))
                    .foregroundColor(DesignSystem.textPrimary)
                Spacer()
                Text("\(provider.modelRemains.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignSystem.textMuted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(DesignSystem.surface)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)

            ForEach(provider.modelRemains) { model in
                ModelRemainCard(model: model)
            }
            .padding(.horizontal, 24)
        }
    }

    private func formatDateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        return formatter.string(from: date)
    }
}

struct ModelRemainCard: View {
    let model: ModelRemain

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(model.modelName)
                    .font(DesignSystem.displayFont(size: 16, weight: .bold))
                    .foregroundColor(DesignSystem.textPrimary)

                Spacer()

                Text("\(Int(model.remainingPercent))% remaining")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(remainingColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(DesignSystem.surfaceHover)
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(remainingColor)
                        .frame(width: geo.size.width * CGFloat(model.remainingPercent / 100), height: 12)
                        .shadow(color: remainingColor.opacity(0.3), radius: 4, x: 0, y: 2)
                }
            }
            .frame(height: 12)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Used")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DesignSystem.textMuted)
                    Text("\(model.usedCount)")
                        .font(DesignSystem.displayFont(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.error)
                }

                Spacer()

                VStack(alignment: .center, spacing: 4) {
                    Text("Total")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DesignSystem.textMuted)
                    Text("\(model.currentIntervalTotalCount)")
                        .font(DesignSystem.displayFont(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.textPrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Remaining")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DesignSystem.textMuted)
                    Text("\(model.remainingCount)")
                        .font(DesignSystem.displayFont(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.success)
                }
            }
        }
        .padding(18)
        .background(DesignSystem.surface)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(DesignSystem.surfaceHover, lineWidth: 1))
    }

    private var remainingColor: Color {
        if model.remainingPercent > 50 {
            return DesignSystem.success
        } else if model.remainingPercent > 20 {
            return DesignSystem.warning
        } else {
            return DesignSystem.error
        }
    }
}
