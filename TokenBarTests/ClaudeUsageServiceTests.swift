import Testing
import Foundation
@testable import TokenBar

@Suite("Claude Usage Service Tests")
struct ClaudeUsageServiceTests {
    @Test("Parses Claude line without fractional seconds and calculates cost")
    @MainActor
    func parsesClaudeLineWithoutFractionalSecondsAndCalculatesCost() async throws {
        let tmp = try temporaryClaudeDir()
        let projects = tmp.appendingPathComponent("projects", isDirectory: true)
        try FileManager.default.createDirectory(at: projects, withIntermediateDirectories: true)

        let sessionDir = projects.appendingPathComponent("demo", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        let fileURL = sessionDir.appendingPathComponent("session-1.jsonl")

        // Timestamp without fractional seconds, cache tokens included
        let line = """
        {"timestamp":"2024-01-02T10:15:30Z","sessionId":"session-1","requestId":"r1","message":{"id":"m1","model":"claude-sonnet-4-20250514","usage":{"input_tokens":1000,"output_tokens":500,"cache_creation_input_tokens":100,"cache_read_input_tokens":50}}}
        """
        try line.appendLine(to: fileURL)

        // ClaudeUsageService reads environment at init time
        setenv("CLAUDE_CONFIG_DIR", tmp.path, 1)
        defer { unsetenv("CLAUDE_CONFIG_DIR") }

        let pricing = StubPricing(cost: Decimal(string: "0.0123")!)
        let service = ClaudeUsageService(fileManager: .default, processInfo: .processInfo, pricing: pricing)

        let snapshot = try await service.fetchUsage(now: Date(timeIntervalSince1970: 1_704_192_000), calendar: .autoupdatingCurrent)
        let today = snapshot.periods.first(where: { $0.period == .today })?.metrics

        #expect(today?.inputTokens == 1000)
        #expect(today?.outputTokens == 500)
        #expect(today?.cacheTokens == 150)
        #expect(today?.costUSD == pricing.cost)

        #expect(snapshot.modelBreakdownToday.first?.modelName == "claude-sonnet-4-20250514")
        #expect(snapshot.modelBreakdownToday.first?.totalTokens == 1650)
    }

    @Test("Aggregates weekly usage using locale week start")
    @MainActor
    func aggregatesWeeklyUsageUsingLocaleWeekStart() async throws {
        let tmp = try temporaryClaudeDir()
        let projects = tmp.appendingPathComponent("projects", isDirectory: true)
        try FileManager.default.createDirectory(at: projects, withIntermediateDirectories: true)

        let sessionDir = projects.appendingPathComponent("demo", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        let fileURL = sessionDir.appendingPathComponent("session-1.jsonl")

        let sundayLine = """
        {"timestamp":"2024-02-04T10:00:00Z","sessionId":"session-1","requestId":"r1","message":{"id":"m1","model":"claude-sonnet-4-20250514","usage":{"input_tokens":100,"output_tokens":50}}}
        """
        let mondayLine = """
        {"timestamp":"2024-02-05T09:00:00Z","sessionId":"session-1","requestId":"r2","message":{"id":"m2","model":"claude-sonnet-4-20250514","usage":{"input_tokens":200,"output_tokens":100}}}
        """
        try [sundayLine, mondayLine].forEach { try $0.appendLine(to: fileURL) }

        setenv("CLAUDE_CONFIG_DIR", tmp.path, 1)
        defer { unsetenv("CLAUDE_CONFIG_DIR") }

        let pricing = StubPricing(cost: Decimal(string: "0.01")!)
        let service = ClaudeUsageService(fileManager: .default, processInfo: .processInfo, pricing: pricing)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "pl_PL")
        calendar.firstWeekday = 2 // Monday
        calendar.minimumDaysInFirstWeek = 4

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let now = formatter.date(from: "2024-02-05T12:00:00Z") ?? Date(timeIntervalSince1970: 1_706_135_200)

        let snapshot = try await service.fetchUsage(now: now, calendar: calendar)
        let week = snapshot.periods.first(where: { $0.period == .week })?.metrics

        #expect(week?.inputTokens == 200)
        #expect(week?.outputTokens == 100)
        #expect(week?.cacheTokens == 0)
        #expect(week?.costUSD == pricing.cost)
        #expect(week?.sessionCount == 1)
    }
}

// MARK: - Test Helpers

private struct StubPricing: ClaudePricingProviding {
    let cost: Decimal

    func cost(for usage: TokenUsage, model: String?, overrideCostUSD: Double?) async -> Decimal {
        if let overrideCostUSD {
            return Decimal(overrideCostUSD)
        }
        return cost
    }
}

private func temporaryClaudeDir() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private extension String {
    func appendLine(to url: URL) throws {
        let data = (self + "\n").data(using: .utf8)!
        if FileManager.default.fileExists(atPath: url.path) {
            let handle = try FileHandle(forWritingTo: url)
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.close()
        } else {
            try data.write(to: url, options: .atomic)
        }
    }
}
