import SwiftUI
import Charts

struct DailyCost: Identifiable {
    let id = UUID()
    let date: Date
    let amount: Double
}

struct DetailView<Provider: AIProviderProtocol>: View {
    @ObservedObject var provider: Provider
    @State private var refreshRotation: Double = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection

                if let error = provider.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }

                Divider()
                    .padding(.horizontal)

                usageOverviewSection

                statisticsGridSection

                if !provider.usageEvents.isEmpty {
                    usageEventsSection
                }

                Spacer()
            }
        }
        .background(Color(red: 0.05, green: 0.05, blue: 0.05))
    }

    private var headerSection: some View {
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
                    Image(systemName: "arrow.up.right")
                    Text(provider.todayUsageString)
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.red)
            }

            Button(action: {
                withAnimation(.easeInOut(duration: 0.6)) {
                    refreshRotation += 360
                }
                Task {
                    await provider.fetchData()
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.gray)
                    .padding(8)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
                    .rotationEffect(.degrees(refreshRotation))
            }
            .buttonStyle(.plain)
            .padding(.leading, 16)
            .padding(.bottom, 8)
            .help("Refresh")
        }
        .padding(.horizontal)
        .padding(.top, 20)
    }

    private var usageOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Usage Overview")
                .font(.system(size: 20, weight: .bold))
                .padding(.horizontal)

            if !(provider is BLTProvider) {
                HStack(spacing: 16) {
                    UsageCard(
                        title: "Included Usage",
                        value: "$\(String(format: "%.2f", provider.includedUsage))",
                        limit: "$\(String(format: "%.0f", provider.includedLimit))",
                        progress: provider.includedLimit > 0 ? provider.includedUsage / provider.includedLimit : 0
                    )

                    UsageCard(
                        title: "On-Demand Usage",
                        value: "$\(String(format: "%.2f", provider.onDemandUsage))",
                        limit: "Unlimited",
                        progress: 0,
                        isUnlimited: true
                    )
                }
                .padding(.horizontal)
            } else {
                HStack(spacing: 16) {
                    UsageCard(
                        title: "Used Quota",
                        value: "$\(String(format: "%.2f", provider.includedUsage))",
                        limit: "Total",
                        progress: 0,
                        isUnlimited: true
                    )

                    UsageCard(
                        title: "Remaining Quota",
                        value: "$\(String(format: "%.2f", provider.balance))",
                        limit: "Current",
                        progress: 0,
                        isUnlimited: true
                    )
                }
                .padding(.horizontal)
            }

            if !provider.usageHistory.isEmpty {
                usageChart
            }

            if !dailyCostData.isEmpty {
                dailyCostChart
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
            Text("Daily Cost")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Chart(dailyCostData) { item in
                BarMark(
                    x: .value("Date", item.date),
                    y: .value("Cost", item.amount),
                    width: .fixed(40)
                )
                .foregroundStyle(Color.red.opacity(0.8))
                .cornerRadius(4)
                .annotation(position: .top) {
                    Text("$\(String(format: "%.2f", item.amount))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .currency(code: "USD"))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 1)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .frame(height: 200)
            .padding(.horizontal)
        }
    }

    private var usageChart: some View {
        Chart {
            ForEach(provider.usageHistory) { usage in
                LineMark(
                    x: .value("Time", usage.date),
                    y: .value("Usage", usage.amount)
                )
                .foregroundStyle(Color.red)

                AreaMark(
                    x: .value("Time", usage.date),
                    y: .value("Usage", usage.amount)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.red.opacity(0.2),
                            Color.red.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .frame(height: 200)
        .padding(.horizontal)
    }

    private var usageEventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Events")
                .font(.system(size: 20, weight: .bold))
                .padding(.horizontal)

            VStack(spacing: 0) {
                // Header
                            HStack {
                                Text("Date").frame(width: 100, alignment: .leading)
                                Text("Model").frame(maxWidth: .infinity, alignment: .leading)
                                Text("In").frame(width: 50, alignment: .trailing)
                                if !(provider is BLTProvider) {
                                    Text("Out").frame(width: 50, alignment: .trailing)
                                    Text("Cache").frame(width: 50, alignment: .trailing)
                                }
                                Text("Total").frame(width: 60, alignment: .trailing)
                                Text("Cost").frame(width: 80, alignment: .trailing)
                                if !(provider is BLTProvider) {
                                    Text("$/1M").frame(width: 60, alignment: .trailing)
                                }
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                            .padding(.horizontal)
                            .background(Color.white.opacity(0.05))

                            ForEach(provider.usageEvents) { event in
                                Divider()
                                HStack {
                                    Text(event.date).frame(width: 100, alignment: .leading)
                                    Text(event.model).frame(maxWidth: .infinity, alignment: .leading)
                                    Text(event.inputTokensFormatted).frame(width: 50, alignment: .trailing)
                                    if !(provider is BLTProvider) {
                                        Text(event.outputTokensFormatted).frame(width: 50, alignment: .trailing)
                                        Text(event.cacheTokensFormatted).frame(width: 50, alignment: .trailing)
                                    }
                                    Text(event.totalTokensFormatted).frame(width: 60, alignment: .trailing)
                                    Text(event.costFormatted).frame(width: 80, alignment: .trailing)
                                    if !(provider is BLTProvider) {
                                        Text(event.pricePerMillion).frame(width: 60, alignment: .trailing)
                                    }
                                }
                                .font(.system(size: 11))
                                .padding(.vertical, 8)
                                .padding(.horizontal)
                            }
            }
            .background(Color.white.opacity(0.03))
            .cornerRadius(8)
            .padding(.horizontal)
        }
    }

    private var statisticsGridSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(title: "Status", value: provider.isLoading ? "Loading..." : "Active", icon: "bolt.fill")
            StatCard(title: "Balance", value: "$\(provider.balanceString)", icon: "dollarsign.circle")
            StatCard(title: "Provider", value: provider.name, icon: "cpu")
            StatCard(title: "Last Sync", value: "Just now", icon: "clock")
        }
        .padding()
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

struct UsageCard: View {
    let title: String
    let value: String
    let limit: String
    let progress: Double
    var isUnlimited: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            HStack(alignment: .bottom, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                Text("/ \(limit)")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 2)
            }

            if !isUnlimited {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.1))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.blue)
                            .frame(width: geo.size.width * CGFloat(min(progress, 1.0)))
                    }
                }
                .frame(height: 4)
            } else {
                Divider()
                    .background(Color.white.opacity(0.1))
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - ZenMux Detail View

struct ZenMuxDetailView: View {
    @ObservedObject var provider: ZenMuxProvider

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection

                if let error = provider.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }

                Divider()
                    .padding(.horizontal)

                usageOverviewSection

                walletSection

                Spacer()
            }
        }
        .background(Color(red: 0.05, green: 0.05, blue: 0.05))
    }

    private var headerSection: some View {
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
            } else {
                Button(action: {
                    Task {
                        await provider.fetchData()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }

    private var usageOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Usage")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.gray)
                .padding(.horizontal)

            HStack(spacing: 16) {
                UsageCard(
                    title: "Total Cost",
                    value: "$\(String(format: "%.6f", provider.todayUsage))",
                    limit: "Today",
                    progress: 0,
                    isUnlimited: true
                )

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Input")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("$\(String(format: "%.6f", provider.todayInputCost))")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }

                    HStack {
                        Text("Output")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("$\(String(format: "%.6f", provider.todayOutputCost))")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }

                    HStack {
                        Text("Requests")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(provider.todayRequestCount)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }

    private var walletSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Wallet Balance")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.gray)
                .padding(.horizontal)

            HStack(spacing: 16) {
                UsageCard(
                    title: "Total Balance",
                    value: "$\(String(format: "%.2f", provider.balance))",
                    limit: "Available",
                    progress: 0,
                    isUnlimited: true
                )

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Charge")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("$\(String(format: "%.2f", provider.chargeBalance))")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.green)
                    }

                    HStack {
                        Text("Discount")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("$\(String(format: "%.2f", provider.discountBalance))")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.orange)
                    }

                    Divider()

                    HStack {
                        Text("Owe")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("$\(String(format: "%.2f", provider.oweFeeSum))")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(provider.oweFeeSum > 0 ? .red : .white)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - MiniMax Detail View

struct MiniMaxDetailView: View {
    @ObservedObject var provider: MiniMaxProvider

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection

                if let error = provider.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }

                Divider()
                    .padding(.horizontal)

                subscriptionSection

                timeWindowSection

                modelListSection

                Spacer()
            }
        }
        .background(Color(red: 0.05, green: 0.05, blue: 0.05))
    }

    private var headerSection: some View {
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
            } else {
                Button(action: {
                    Task {
                        await provider.fetchData()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }

    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Subscription")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.gray)
                .padding(.horizontal)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Plan")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(provider.currentSubscriptionTitle.isEmpty ? "--" : provider.currentSubscriptionTitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }

                Spacer()

                if let combo = provider.currentComboCard {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Price")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text(combo.priceString)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.green)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Cycle")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text(combo.cycleString)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                }

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Expires")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(provider.currentSubscriptionEndDate.isEmpty ? "--" : provider.currentSubscriptionEndDate)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.orange)
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    private var timeWindowSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Period")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.gray)
                .padding(.horizontal)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Time Window")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    if let start = provider.currentPeriodStart, let end = provider.currentPeriodEnd {
                        Text(formatDateRange(start: start, end: end))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    } else {
                        Text("--")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Next Refresh")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    if let end = provider.currentPeriodEnd {
                        Text(formatDate(end))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.orange)
                    } else {
                        Text("--")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    private var modelListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Models")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.gray)
                .padding(.horizontal)

            ForEach(provider.modelRemains) { model in
                ModelRemainCard(model: model)
            }
            .padding(.horizontal)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(model.modelName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Text("\(Int(model.remainingPercent))% remaining")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(remainingColor)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(remainingColor)
                        .frame(width: geometry.size.width * CGFloat(model.remainingPercent / 100), height: 12)
                }
            }
            .frame(height: 12)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Used")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("\(model.usedCount)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.red)
                }

                Spacer()

                VStack(alignment: .center, spacing: 2) {
                    Text("Total")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("\(model.currentIntervalTotalCount)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Remaining")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("\(model.remainingCount)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    private var remainingColor: Color {
        if model.remainingPercent > 50 {
            return .green
        } else if model.remainingPercent > 20 {
            return .orange
        } else {
            return .red
        }
    }
}
