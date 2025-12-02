import Foundation

protocol UsageProviding {
    func fetchDailyUsage() -> UsageSnapshot
}

struct SampleUsageProvider: UsageProviding {
    func fetchDailyUsage() -> UsageSnapshot {
        let codex = UsageSummary(
            agent: .codex,
            sessions: 4,
            promptTokens: 3200,
            completionTokens: 1800,
            estimatedCostUSD: Decimal(string: "0.062") ?? .zero
        )

        let claude = UsageSummary(
            agent: .claude,
            sessions: 3,
            promptTokens: 2600,
            completionTokens: 2100,
            estimatedCostUSD: Decimal(string: "0.049") ?? .zero
        )

        return UsageSnapshot(
            summaries: [codex, claude],
            updatedAt: Date()
        )
    }
}
