import Combine
import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshot: UsageSnapshot?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let service: ClaudeUsageServicing
    private let calendar: Calendar
    private var refreshTimer: Timer?

    init(service: ClaudeUsageServicing, calendar: Calendar = .autoupdatingCurrent) {
        self.service = service
        self.calendar = calendar
    }

    func refresh(now: Date = Date()) {
        Task {
            await load(now: now)
        }
    }

    func startAutoRefresh(interval: TimeInterval = 60) {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.refresh()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func load(now: Date) async {
        isLoading = true
        errorMessage = nil
        do {
            snapshot = try await service.fetchUsage(now: now, calendar: calendar)
        } catch {
            snapshot = nil
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

extension UsageStore {
    static func preview() -> UsageStore {
        let service = PreviewUsageService()
        return UsageStore(service: service, calendar: .autoupdatingCurrent)
    }
}

private struct PreviewUsageService: ClaudeUsageServicing {
    func fetchUsage(now: Date, calendar: Calendar) async throws -> UsageSnapshot {
        let today = UsageMetrics(inputTokens: 2_400, outputTokens: 1_200, cacheTokens: 300, costUSD: Decimal(string: "0.07") ?? .zero, sessionCount: 3)
        let week = UsageMetrics(inputTokens: 11_400, outputTokens: 5_600, cacheTokens: 1_400, costUSD: Decimal(string: "0.31") ?? .zero, sessionCount: 9)
        let month = UsageMetrics(inputTokens: 42_000, outputTokens: 21_800, cacheTokens: 4_800, costUSD: Decimal(string: "1.12") ?? .zero, sessionCount: 21)

        let periods = [
            PeriodUsage(period: .today, metrics: today),
            PeriodUsage(period: .week, metrics: week),
            PeriodUsage(period: .month, metrics: month),
        ]

        let models = [
            ModelUsage(modelName: "claude-sonnet-4-20250514", inputTokens: 1_200, outputTokens: 600, cacheTokens: 200, costUSD: Decimal(string: "0.04") ?? .zero),
            ModelUsage(modelName: "claude-opus-4-20250514", inputTokens: 800, outputTokens: 300, cacheTokens: 100, costUSD: Decimal(string: "0.03") ?? .zero),
        ]

        return UsageSnapshot(
            periods: periods,
            modelBreakdownToday: models,
            updatedAt: now
        )
    }
}
