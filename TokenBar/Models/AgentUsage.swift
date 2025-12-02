import Foundation
import SwiftUI

enum AgentKind: String, CaseIterable, Identifiable {
    case codex
    case claude

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .codex:
            return "Codex"
        case .claude:
            return "Claude"
        }
    }

    var symbolName: String {
        switch self {
        case .codex:
            return "curlybraces"
        case .claude:
            return "brain.head.profile"
        }
    }

    var accentColor: Color {
        switch self {
        case .codex:
            return Color.blue
        case .claude:
            return Color.purple
        }
    }
}

struct UsageSummary: Identifiable {
    let id = UUID()
    let agent: AgentKind
    let sessions: Int
    let promptTokens: Int
    let completionTokens: Int
    let estimatedCostUSD: Decimal

    var totalTokens: Int {
        promptTokens + completionTokens
    }
}

struct UsageSnapshot {
    let summaries: [UsageSummary]
    let updatedAt: Date

    var totalTokens: Int {
        summaries.reduce(into: 0) { partial, summary in
            partial += summary.totalTokens
        }
    }

    var totalCostUSD: Decimal {
        summaries.reduce(into: Decimal.zero) { partial, summary in
            partial += summary.estimatedCostUSD
        }
    }
}
