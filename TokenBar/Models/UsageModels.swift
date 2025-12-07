import Foundation
import SwiftUI

enum UsagePeriod: String, CaseIterable, Identifiable {
    case today
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today:
            return "Today"
        case .week:
            return "This Week"
        case .month:
            return "This Month"
        }
    }

    var symbolName: String {
        switch self {
        case .today:
            return "sun.max.fill"
        case .week:
            return "calendar"
        case .month:
            return "calendar.badge.clock"
        }
    }

    var accentColor: Color {
        switch self {
        case .today:
            return .blue
        case .week:
            return .green
        case .month:
            return .orange
        }
    }
}

struct UsageMetrics {
    let inputTokens: Int
    let outputTokens: Int
    let cacheTokens: Int
    let costUSD: Decimal
    let sessionCount: Int

    var totalTokens: Int {
        inputTokens + outputTokens + cacheTokens
    }
}

struct PeriodUsage: Identifiable {
    let period: UsagePeriod
    let metrics: UsageMetrics

    var id: String { period.id }
}

struct ModelUsage: Identifiable {
    let modelName: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheTokens: Int
    let costUSD: Decimal

    var id: String { modelName }

    var totalTokens: Int {
        inputTokens + outputTokens + cacheTokens
    }
}

struct SessionUsage: Identifiable {
    let sessionId: String
    let displayName: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheTokens: Int
    let costUSD: Decimal
    let firstSeen: Date
    let lastSeen: Date
    let requestCount: Int

    var id: String { sessionId }

    var totalTokens: Int {
        inputTokens + outputTokens + cacheTokens
    }
}

struct UsageSnapshot {
    let periods: [PeriodUsage]
    let modelBreakdownToday: [ModelUsage]
    let sessionBreakdownToday: [SessionUsage]
    let updatedAt: Date

    var todayMetrics: UsageMetrics? {
        periods.first { $0.period == .today }?.metrics
    }

    var totalTokens: Int {
        periods.reduce(into: 0) { $0 += $1.metrics.totalTokens }
    }

    var totalCostUSD: Decimal {
        periods.reduce(into: Decimal.zero) { $0 += $1.metrics.costUSD }
    }
}
