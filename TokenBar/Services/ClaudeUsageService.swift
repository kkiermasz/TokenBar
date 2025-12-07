import Foundation
import OSLog

protocol ClaudeUsageServicing {
    func fetchUsage(now: Date, calendar: Calendar) async throws -> UsageSnapshot
}

struct ClaudeUsageService: ClaudeUsageServicing {
    private let fileManager: FileManager
    private let processInfo: ProcessInfo
    private let pricing: ClaudePricingProviding
    private let logger = Logger(subsystem: "app.tokenbar", category: "claude-usage")

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoNoFractionFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    init(
        fileManager: FileManager = .default,
        processInfo: ProcessInfo = .processInfo,
        pricing: ClaudePricingProviding = ClaudePricingService()
    ) {
        self.fileManager = fileManager
        self.processInfo = processInfo
        self.pricing = pricing
    }

    func fetchUsage(now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) async throws -> UsageSnapshot {
        // For the status bar we only surface Claude Code usage; Codex data is intentionally excluded
        // to avoid mixing sources and inflating totals.
        let discoveredFiles = claudeRoots().flatMap { discoverJSONLFiles(in: $0, source: .claude) }

        if discoveredFiles.isEmpty {
            return UsageSnapshot(periods: UsagePeriod.allCases.map { period in
                PeriodUsage(
                    period: period,
                    metrics: UsageMetrics(
                        inputTokens: 0,
                        outputTokens: 0,
                        cacheTokens: 0,
                        costUSD: .zero,
                        sessionCount: 0
                    )
                )
            }, modelBreakdownToday: [], sessionBreakdownToday: [], updatedAt: now)
        }

        var entries: [UsageEntry] = []

        for file in discoveredFiles {
            do {
                let fileEntries: [UsageEntry]
                switch file.source {
                case .claude:
                    fileEntries = try await readClaudeEntries(from: file.url, sessionHint: file.sessionId, pricing: pricing)
                case .codex:
                    fileEntries = try await readCodexEntries(from: file.url, sessionId: file.sessionId)
                }
                entries.append(contentsOf: fileEntries)
            } catch {
                logger.debug("Skipping \(file.url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        let scopedCalendar = configuredCalendar(from: calendar)
        return aggregate(entries: entries, now: now, calendar: scopedCalendar)
    }
}

// MARK: - Discovery

private extension ClaudeUsageService {
    enum Source {
        case claude
        case codex
    }

    struct DiscoveredFile {
        let url: URL
        let sessionId: String?
        let source: Source
    }

    func claudeRoots() -> [URL] {
        var candidates: [URL] = []

        if let envValue = processInfo.environment["CLAUDE_CONFIG_DIR"], envValue.isEmpty == false {
            let paths = envValue.split(separator: ",").map { URL(fileURLWithPath: String($0.trimmingCharacters(in: .whitespaces))) }
            candidates.append(contentsOf: paths)
        } else {
            let home = fileManager.homeDirectoryForCurrentUser
            candidates = [
                home.appendingPathComponent(".config/claude", isDirectory: true),
                home.appendingPathComponent(".claude", isDirectory: true),
            ]
        }

        let validRoots = candidates.compactMap { root -> URL? in
            let projects = root.appendingPathComponent("projects", isDirectory: true)
            var isDirectory: ObjCBool = false
            let exists = fileManager.fileExists(atPath: projects.path, isDirectory: &isDirectory)
            return exists && isDirectory.boolValue ? projects : nil
        }

        if validRoots.isEmpty {
            let searched = candidates.map(\.path).joined(separator: ", ")
            logger.debug("No Claude directories found. Searched: \(searched, privacy: .public)")
        }

        return validRoots
    }

    func codexSessionRoots() -> [URL] {
        var roots: [URL] = []
        if let envValue = processInfo.environment["CODEX_HOME"], envValue.isEmpty == false {
            roots.append(URL(fileURLWithPath: envValue).appendingPathComponent("sessions", isDirectory: true))
        } else {
            let home = fileManager.homeDirectoryForCurrentUser
            roots.append(home.appendingPathComponent(".codex/sessions", isDirectory: true))
        }

        return roots.filter { url in
            var isDir: ObjCBool = false
            return fileManager.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
        }
    }

    func discoverJSONLFiles(in projectsRoot: URL, source: Source) -> [DiscoveredFile] {
        guard let enumerator = fileManager.enumerator(at: projectsRoot, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return []
        }

        var results: [DiscoveredFile] = []
        for case let url as URL in enumerator {
            if url.pathExtension.lowercased() == "jsonl" {
                let sessionId = url.deletingPathExtension().lastPathComponent
                results.append(DiscoveredFile(url: url, sessionId: sessionId, source: source))
            }
        }

        return results
    }
}

// MARK: - Parsing

private extension ClaudeUsageService {
    struct UsageEntry {
        let timestamp: Date
        let sessionId: String?
        let requestId: String?
        let messageId: String?
        let model: String?
        let usage: UsagePayload.Message.Usage
        let cost: Decimal
        let cwd: String?
        let gitBranch: String?
    }

    struct UsagePayload: Decodable {
        struct Message: Decodable {
            struct Usage: Decodable {
                let inputTokens: Int?
                let outputTokens: Int?
                let cacheCreationInputTokens: Int?
                let cacheReadInputTokens: Int?
            }

            let usage: Usage?
            let model: String?
            let id: String?
        }

        let timestamp: Date
        let sessionId: String?
        let requestId: String?
        let costUSD: Double?
        let message: Message
        let cwd: String?
        let gitBranch: String?

        var uniqueHash: String? {
            guard let messageId = message.id, let requestId else { return nil }
            return "\(messageId):\(requestId)"
        }
    }

    func readClaudeEntries(
        from url: URL,
        sessionHint: String?,
        pricing: ClaudePricingProviding
    ) async throws -> [UsageEntry] {
        var dedupe = Set<String>()
        var entries: [UsageEntry] = []

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = ClaudeUsageService.isoFormatter.date(from: raw) ?? ClaudeUsageService.isoNoFractionFormatter.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid ISO8601 timestamp"))
        }
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        for try await rawLine in handle.bytes.lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty {
                continue
            }

            guard let data = line.data(using: .utf8) else {
                continue
            }

            guard let payload = try? decoder.decode(UsagePayload.self, from: data) else {
                continue
            }

            guard let usage = payload.message.usage else {
                continue
            }

            if let hash = payload.uniqueHash {
                if dedupe.contains(hash) {
                    continue
                }
                dedupe.insert(hash)
            }

            let cost = await pricing.cost(
                for: TokenUsage(
                    inputTokens: payload.message.usage?.inputTokens ?? 0,
                    outputTokens: payload.message.usage?.outputTokens ?? 0,
                    cacheCreationTokens: payload.message.usage?.cacheCreationInputTokens ?? 0,
                    cacheReadTokens: payload.message.usage?.cacheReadInputTokens ?? 0
                ),
                model: payload.message.model,
                overrideCostUSD: payload.costUSD
            )

            entries.append(
                UsageEntry(
                    timestamp: payload.timestamp,
                    sessionId: payload.sessionId ?? sessionHint,
                    requestId: payload.requestId,
                    messageId: payload.message.id,
                    model: payload.message.model,
                    usage: usage,
                    cost: cost,
                    cwd: payload.cwd,
                    gitBranch: payload.gitBranch
                )
            )
        }

        return entries
    }

    struct CodexRawUsage {
        let inputTokens: Int
        let cachedInputTokens: Int
        let outputTokens: Int
        let reasoningOutputTokens: Int
        let totalTokens: Int
    }

    func parseRawUsage(_ value: Any?) -> CodexRawUsage? {
        guard let dict = value as? [String: Any] else { return nil }

        func asInt(_ key: String) -> Int {
            guard let number = dict[key] as? NSNumber else { return 0 }
            return number.intValue
        }

        let input = asInt("input_tokens")
        let cached = asInt("cached_input_tokens") > 0 ? asInt("cached_input_tokens") : asInt("cache_read_input_tokens")
        let output = asInt("output_tokens")
        let reasoning = asInt("reasoning_output_tokens")
        let total = asInt("total_tokens")

        return CodexRawUsage(
            inputTokens: input,
            cachedInputTokens: cached,
            outputTokens: output,
            reasoningOutputTokens: reasoning,
            totalTokens: total > 0 ? total : input + output
        )
    }

    func subtractRawUsage(current: CodexRawUsage, previous: CodexRawUsage?) -> CodexRawUsage {
        CodexRawUsage(
            inputTokens: max(current.inputTokens - (previous?.inputTokens ?? 0), 0),
            cachedInputTokens: max(current.cachedInputTokens - (previous?.cachedInputTokens ?? 0), 0),
            outputTokens: max(current.outputTokens - (previous?.outputTokens ?? 0), 0),
            reasoningOutputTokens: max(current.reasoningOutputTokens - (previous?.reasoningOutputTokens ?? 0), 0),
            totalTokens: max(current.totalTokens - (previous?.totalTokens ?? 0), 0)
        )
    }

    func readCodexEntries(from url: URL, sessionId: String?) async throws -> [UsageEntry] {
        var entries: [UsageEntry] = []
        var previousTotals: CodexRawUsage?

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        for try await rawLine in handle.bytes.lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty {
                continue
            }

            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String else {
                continue
            }

            guard let timestampString = json["timestamp"] as? String,
                  let timestamp = ClaudeUsageService.isoFormatter.date(from: timestampString) else {
                continue
            }

            if type != "event_msg" {
                continue
            }

            guard let payload = json["payload"] as? [String: Any],
                  let info = payload["info"] as? [String: Any] else {
                continue
            }

            let lastUsage = parseRawUsage(info["last_token_usage"])
            let totalUsage = parseRawUsage(info["total_token_usage"])

            var raw = lastUsage
            if raw == nil, let total = totalUsage {
                raw = subtractRawUsage(current: total, previous: previousTotals)
            }

            if let total = totalUsage {
                previousTotals = total
            }

            guard let usage = raw else { continue }
            if usage.inputTokens == 0 && usage.cachedInputTokens == 0 && usage.outputTokens == 0 && usage.reasoningOutputTokens == 0 {
                continue
            }

            let messageId = payload["message_id"] as? String
            let requestId = payload["request_id"] as? String
            let model = info["model"] as? String

            entries.append(
                UsageEntry(
                    timestamp: timestamp,
                    sessionId: sessionId,
                    requestId: requestId,
                    messageId: messageId,
                    model: model,
                    usage: UsagePayload.Message.Usage(
                        inputTokens: usage.inputTokens,
                        outputTokens: usage.outputTokens,
                        cacheCreationInputTokens: 0,
                        cacheReadInputTokens: usage.cachedInputTokens
                    ),
                    cost: .zero,
                    cwd: nil,
                    gitBranch: nil
                )
            )
        }

        return entries
    }
}

// MARK: - Aggregation

private extension ClaudeUsageService {
    func aggregate(entries: [UsageEntry], now: Date, calendar: Calendar) -> UsageSnapshot {
        let startOfDay = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now)
            ?? DateInterval(start: startOfDay, end: startOfTomorrow)
        let monthInterval = calendar.dateInterval(of: .month, for: now)
            ?? DateInterval(start: startOfDay, end: startOfTomorrow)

        let periods: [PeriodUsage] = [
            PeriodUsage(period: .today, metrics: summarize(entries, within: startOfDay..<startOfTomorrow)),
            PeriodUsage(period: .week, metrics: summarize(entries, within: weekInterval.start..<weekInterval.end)),
            PeriodUsage(period: .month, metrics: summarize(entries, within: monthInterval.start..<monthInterval.end)),
        ]

        let models = summarizeModels(entries, within: startOfDay..<startOfTomorrow)
        let sessions = summarizeSessions(entries, within: startOfDay..<startOfTomorrow)

        return UsageSnapshot(
            periods: periods,
            modelBreakdownToday: models,
            sessionBreakdownToday: sessions,
            updatedAt: now
        )
    }

    func summarize(_ entries: [UsageEntry], within window: Range<Date>) -> UsageMetrics {
        var input = 0
        var output = 0
        var cache = 0
        var cost = Decimal.zero
        var sessions = Set<String>()

        for entry in entries where window.contains(entry.timestamp) {
            input += entry.usage.inputTokens ?? 0
            output += entry.usage.outputTokens ?? 0
            cache += (entry.usage.cacheCreationInputTokens ?? 0) + (entry.usage.cacheReadInputTokens ?? 0)
            cost += entry.cost
            if let sessionId = entry.sessionId {
                sessions.insert(sessionId)
            }
        }

        return UsageMetrics(
            inputTokens: input,
            outputTokens: output,
            cacheTokens: cache,
            costUSD: cost,
            sessionCount: sessions.count
        )
    }

    func summarizeModels(_ entries: [UsageEntry], within window: Range<Date>) -> [ModelUsage] {
        var aggregates: [String: (input: Int, output: Int, cache: Int, cost: Decimal)] = [:]

        for entry in entries where window.contains(entry.timestamp) {
            let name = entry.model ?? "unknown"
            let cacheTokens = (entry.usage.cacheCreationInputTokens ?? 0) + (entry.usage.cacheReadInputTokens ?? 0)
            var aggregate = aggregates[name] ?? (input: 0, output: 0, cache: 0, cost: .zero)
            aggregate.input += entry.usage.inputTokens ?? 0
            aggregate.output += entry.usage.outputTokens ?? 0
            aggregate.cache += cacheTokens
            aggregate.cost += entry.cost
            aggregates[name] = aggregate
        }

        return aggregates
            .map { name, value in
                ModelUsage(
                    modelName: name,
                    inputTokens: value.input,
                    outputTokens: value.output,
                    cacheTokens: value.cache,
                    costUSD: value.cost
                )
            }
            .sorted { lhs, rhs in
                if lhs.costUSD == rhs.costUSD {
                    return lhs.totalTokens > rhs.totalTokens
                }
                return lhs.costUSD > rhs.costUSD
            }
    }

    func summarizeSessions(_ entries: [UsageEntry], within window: Range<Date>) -> [SessionUsage] {
        var sessionData: [String: (
            cwd: String?,
            branch: String?,
            input: Int,
            output: Int,
            cache: Int,
            cost: Decimal,
            firstSeen: Date,
            lastSeen: Date,
            requestCount: Int
        )] = [:]

        for entry in entries where window.contains(entry.timestamp) {
            guard let sessionId = entry.sessionId else { continue }

            let cacheTokens = (entry.usage.cacheCreationInputTokens ?? 0) +
                             (entry.usage.cacheReadInputTokens ?? 0)

            if var data = sessionData[sessionId] {
                data.input += entry.usage.inputTokens ?? 0
                data.output += entry.usage.outputTokens ?? 0
                data.cache += cacheTokens
                data.cost += entry.cost
                data.firstSeen = min(data.firstSeen, entry.timestamp)
                data.lastSeen = max(data.lastSeen, entry.timestamp)
                data.requestCount += 1
                data.cwd = data.cwd ?? entry.cwd
                data.branch = data.branch ?? entry.gitBranch
                sessionData[sessionId] = data
            } else {
                sessionData[sessionId] = (
                    cwd: entry.cwd,
                    branch: entry.gitBranch,
                    input: entry.usage.inputTokens ?? 0,
                    output: entry.usage.outputTokens ?? 0,
                    cache: cacheTokens,
                    cost: entry.cost,
                    firstSeen: entry.timestamp,
                    lastSeen: entry.timestamp,
                    requestCount: 1
                )
            }
        }

        return sessionData.map { sessionId, data in
            let displayName = deriveSessionDisplayName(
                cwd: data.cwd,
                branch: data.branch,
                sessionId: sessionId
            )

            return SessionUsage(
                sessionId: sessionId,
                displayName: displayName,
                inputTokens: data.input,
                outputTokens: data.output,
                cacheTokens: data.cache,
                costUSD: data.cost,
                firstSeen: data.firstSeen,
                lastSeen: data.lastSeen,
                requestCount: data.requestCount
            )
        }.sorted { lhs, rhs in
            lhs.lastSeen > rhs.lastSeen
        }
    }

    func deriveSessionDisplayName(cwd: String?, branch: String?, sessionId: String) -> String {
        if let cwd = cwd {
            let projectName = URL(fileURLWithPath: cwd).lastPathComponent
            if let branch = branch {
                return "\(projectName) (\(branch))"
            }
            return projectName
        }

        let suffix = String(sessionId.suffix(8))
        return "Session \(suffix)"
    }

    func configuredCalendar(from base: Calendar) -> Calendar {
        var calendar = Calendar(identifier: base.identifier)
        calendar.timeZone = base.timeZone
        calendar.locale = base.locale
        calendar.firstWeekday = base.firstWeekday
        calendar.minimumDaysInFirstWeek = base.minimumDaysInFirstWeek
        return calendar
    }
}
