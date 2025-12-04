import Testing
import Foundation
@testable import TokenBar

@Suite("Claude Usage Service Tests")
struct ClaudeUsageServiceTests {
    @Test("Parses Claude line without fractional seconds and calculates cost")
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
