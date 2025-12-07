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

        let pricing = StubPricing(cost: Decimal(string: "0.0123") ?? .zero)
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

        let pricing = StubPricing(cost: Decimal(string: "0.01") ?? .zero)
        let service = ClaudeUsageService(fileManager: .default, processInfo: .processInfo, pricing: pricing)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
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

    @Test("Aggregates sessions with display names from cwd and branch")
    @MainActor
    func aggregatesSessionsWithDisplayNamesFromCwdAndBranch() async throws {
        let tmp = try temporaryClaudeDir()
        let projects = tmp.appendingPathComponent("projects", isDirectory: true)
        try FileManager.default.createDirectory(at: projects, withIntermediateDirectories: true)

        let sessionDir = projects.appendingPathComponent("demo", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        let fileURL = sessionDir.appendingPathComponent("session-1.jsonl")

        let session1Line = """
        {"timestamp":"2024-01-02T10:00:00Z","sessionId":"sess-1","requestId":"r1","cwd":"/Users/test/MyProject","gitBranch":"main","message":{"id":"m1","model":"claude-sonnet-4-20250514","usage":{"input_tokens":1000,"output_tokens":500}}}
        """
        let session2Line = """
        {"timestamp":"2024-01-02T11:00:00Z","sessionId":"sess-2","requestId":"r2","cwd":"/Users/test/OtherProject","gitBranch":"feature-x","message":{"id":"m2","model":"claude-sonnet-4-20250514","usage":{"input_tokens":800,"output_tokens":400}}}
        """

        try [session1Line, session2Line].forEach { try $0.appendLine(to: fileURL) }

        setenv("CLAUDE_CONFIG_DIR", tmp.path, 1)
        defer { unsetenv("CLAUDE_CONFIG_DIR") }

        let pricing = StubPricing(cost: .zero)
        let service = ClaudeUsageService(fileManager: .default, processInfo: .processInfo, pricing: pricing)

        let snapshot = try await service.fetchUsage(
            now: Date(timeIntervalSince1970: 1_704_192_000),
            calendar: .autoupdatingCurrent
        )

        #expect(snapshot.sessionBreakdownToday.count == 2)

        let session1 = snapshot.sessionBreakdownToday.first { $0.sessionId == "sess-1" }
        #expect(session1?.displayName == "MyProject (main)")
        #expect(session1?.inputTokens == 1000)
        #expect(session1?.outputTokens == 500)
        #expect(session1?.requestCount == 1)

        let session2 = snapshot.sessionBreakdownToday.first { $0.sessionId == "sess-2" }
        #expect(session2?.displayName == "OtherProject (feature-x)")
        #expect(session2?.inputTokens == 800)
        #expect(session2?.outputTokens == 400)
    }

    @Test("Sessions sorted by most recent activity")
    @MainActor
    func sessionsSortedByMostRecentActivity() async throws {
        let tmp = try temporaryClaudeDir()
        let projects = tmp.appendingPathComponent("projects", isDirectory: true)
        try FileManager.default.createDirectory(at: projects, withIntermediateDirectories: true)

        let sessionDir = projects.appendingPathComponent("demo", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        let fileURL = sessionDir.appendingPathComponent("session-1.jsonl")

        // Earlier session
        let olderLine = """
        {"timestamp":"2024-01-02T08:00:00Z","sessionId":"sess-old","requestId":"r1","cwd":"/Users/test/Old","message":{"id":"m1","model":"claude-sonnet-4-20250514","usage":{"input_tokens":100,"output_tokens":50}}}
        """
        // Recent session
        let newerLine = """
        {"timestamp":"2024-01-02T12:00:00Z","sessionId":"sess-new","requestId":"r2","cwd":"/Users/test/New","message":{"id":"m2","model":"claude-sonnet-4-20250514","usage":{"input_tokens":200,"output_tokens":100}}}
        """

        try [olderLine, newerLine].forEach { try $0.appendLine(to: fileURL) }

        setenv("CLAUDE_CONFIG_DIR", tmp.path, 1)
        defer { unsetenv("CLAUDE_CONFIG_DIR") }

        let pricing = StubPricing(cost: .zero)
        let service = ClaudeUsageService(fileManager: .default, processInfo: .processInfo, pricing: pricing)

        let snapshot = try await service.fetchUsage(
            now: Date(timeIntervalSince1970: 1_704_192_000),
            calendar: .autoupdatingCurrent
        )

        #expect(snapshot.sessionBreakdownToday.count == 2)
        #expect(snapshot.sessionBreakdownToday.first?.sessionId == "sess-new")
        #expect(snapshot.sessionBreakdownToday.last?.sessionId == "sess-old")
    }

    @Test("Session fallback to ID when cwd missing")
    @MainActor
    func sessionFallbackToIdWhenCwdMissing() async throws {
        let tmp = try temporaryClaudeDir()
        let projects = tmp.appendingPathComponent("projects", isDirectory: true)
        try FileManager.default.createDirectory(at: projects, withIntermediateDirectories: true)

        let sessionDir = projects.appendingPathComponent("demo", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        let fileURL = sessionDir.appendingPathComponent("session-1.jsonl")

        let line = """
        {"timestamp":"2024-01-02T10:00:00Z","sessionId":"abcd1234-5678-90ef-ghij-klmnopqrstuv","requestId":"r1","message":{"id":"m1","model":"claude-sonnet-4-20250514","usage":{"input_tokens":100,"output_tokens":50}}}
        """

        try line.appendLine(to: fileURL)

        setenv("CLAUDE_CONFIG_DIR", tmp.path, 1)
        defer { unsetenv("CLAUDE_CONFIG_DIR") }

        let pricing = StubPricing(cost: .zero)
        let service = ClaudeUsageService(fileManager: .default, processInfo: .processInfo, pricing: pricing)

        let snapshot = try await service.fetchUsage(
            now: Date(timeIntervalSince1970: 1_704_192_000),
            calendar: .autoupdatingCurrent
        )

        let session = snapshot.sessionBreakdownToday.first
        #expect(session?.displayName == "Session opqrstuv")
    }

    @Test("Session aggregates multiple requests")
    @MainActor
    func sessionAggregatesMultipleRequests() async throws {
        let tmp = try temporaryClaudeDir()
        let projects = tmp.appendingPathComponent("projects", isDirectory: true)
        try FileManager.default.createDirectory(at: projects, withIntermediateDirectories: true)

        let sessionDir = projects.appendingPathComponent("demo", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        let fileURL = sessionDir.appendingPathComponent("session-1.jsonl")

        let req1 = """
        {"timestamp":"2024-01-02T10:00:00Z","sessionId":"sess-1","requestId":"r1","cwd":"/Users/test/Proj","message":{"id":"m1","model":"claude-sonnet-4-20250514","usage":{"input_tokens":100,"output_tokens":50}}}
        """
        let req2 = """
        {"timestamp":"2024-01-02T10:05:00Z","sessionId":"sess-1","requestId":"r2","cwd":"/Users/test/Proj","message":{"id":"m2","model":"claude-sonnet-4-20250514","usage":{"input_tokens":200,"output_tokens":100}}}
        """
        let req3 = """
        {"timestamp":"2024-01-02T10:10:00Z","sessionId":"sess-1","requestId":"r3","cwd":"/Users/test/Proj","message":{"id":"m3","model":"claude-sonnet-4-20250514","usage":{"input_tokens":300,"output_tokens":150}}}
        """

        try [req1, req2, req3].forEach { try $0.appendLine(to: fileURL) }

        setenv("CLAUDE_CONFIG_DIR", tmp.path, 1)
        defer { unsetenv("CLAUDE_CONFIG_DIR") }

        let pricing = StubPricing(cost: Decimal(string: "0.01") ?? .zero)
        let service = ClaudeUsageService(fileManager: .default, processInfo: .processInfo, pricing: pricing)

        let snapshot = try await service.fetchUsage(
            now: Date(timeIntervalSince1970: 1_704_192_000),
            calendar: .autoupdatingCurrent
        )

        let session = snapshot.sessionBreakdownToday.first
        #expect(session?.sessionId == "sess-1")
        #expect(session?.inputTokens == 600)
        #expect(session?.outputTokens == 300)
        #expect(session?.requestCount == 3)
        #expect(session?.costUSD == Decimal(string: "0.03"))
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

private enum TestHelperError: Error {
    case stringEncodingFailed
}

private extension String {
    func appendLine(to url: URL) throws {
        guard let data = (self + "\n").data(using: .utf8) else {
            throw TestHelperError.stringEncodingFailed
        }
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
