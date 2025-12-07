import Foundation
import OSLog

struct TokenUsage {
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int
}

protocol ClaudePricingProviding {
    func cost(for usage: TokenUsage, model: String?, overrideCostUSD: Double?) async -> Decimal
}

final class ClaudePricingService: ClaudePricingProviding {
    private struct ModelPricing: Decodable {
        let inputCostPerToken: Double?
        let outputCostPerToken: Double?
        let cacheCreationInputTokenCost: Double?
        let cacheReadInputTokenCost: Double?
        let inputCostPerTokenAbove200kTokens: Double?
        let outputCostPerTokenAbove200kTokens: Double?
        let cacheCreationInputTokenCostAbove200kTokens: Double?
        let cacheReadInputTokenCostAbove200kTokens: Double?

        enum CodingKeys: String, CodingKey {
            case inputCostPerToken = "input_cost_per_token"
            case outputCostPerToken = "output_cost_per_token"
            case cacheCreationInputTokenCost = "cache_creation_input_token_cost"
            case cacheReadInputTokenCost = "cache_read_input_token_cost"
            case inputCostPerTokenAbove200kTokens = "input_cost_per_token_above_200k_tokens"
            case outputCostPerTokenAbove200kTokens = "output_cost_per_token_above_200k_tokens"
            case cacheCreationInputTokenCostAbove200kTokens = "cache_creation_input_token_cost_above_200k_tokens"
            case cacheReadInputTokenCostAbove200kTokens = "cache_read_input_token_cost_above_200k_tokens"
        }
    }

    private let session: URLSession
    private let logger = Logger(subsystem: "app.tokenbar", category: "claude-pricing")
    private let providerPrefixes = [
        "anthropic/",
        "claude-3-5-",
        "claude-3-",
        "claude-",
        "openrouter/openai/",
    ]
    private let pricingURL: URL

    private var cachedPricing: [String: ModelPricing]?
    private var fetchTask: Task<[String: ModelPricing], Error>?

    init(session: URLSession = .shared) {
        self.session = session
        // This URL is a constant and should always be valid
        guard let url = URL(string: "https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json") else {
            preconditionFailure("Invalid hardcoded pricing URL")
        }
        self.pricingURL = url
    }

    func cost(for usage: TokenUsage, model: String?, overrideCostUSD: Double?) async -> Decimal {
        if let overrideCostUSD {
            return Decimal(overrideCostUSD)
        }

        guard let model, let pricing = await pricing(for: model) else {
            return .zero
        }

        let cost = calculateCost(tokens: usage, pricing: pricing)
        return Decimal(cost)
    }
}

private extension ClaudePricingService {
    private func pricing(for model: String) async -> ModelPricing? {
        guard let dataset = await loadPricing() else { return nil }

        let candidates = [model] + providerPrefixes.map { "\($0)\(model)" }
        for candidate in candidates {
            if let pricing = dataset[candidate] {
                return pricing
            }
        }

        let lower = model.lowercased()
        return dataset.first { key, _ in
            let comparison = key.lowercased()
            return comparison.contains(lower) || lower.contains(comparison)
        }?.value
    }

    private func loadPricing() async -> [String: ModelPricing]? {
        if let cachedPricing {
            return cachedPricing
        }

        if let fetchTask {
            return try? await fetchTask.value
        }

        let task = Task { () throws -> [String: ModelPricing] in
            let (data, response) = try await session.data(from: pricingURL)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            let decoder = JSONDecoder()
            let root = try decoder.decode([String: ModelPricing?].self, from: data)
            return root.compactMapValues { $0 }
        }

        fetchTask = task

        do {
            let pricing = try await task.value
            cachedPricing = pricing
            return pricing
        } catch {
            logger.error("Failed to fetch LiteLLM pricing: \(error.localizedDescription, privacy: .public)")
            fetchTask = nil
            return cachedPricing
        }
    }

    private func calculateCost(tokens: TokenUsage, pricing: ModelPricing) -> Double {
        let threshold = 200_000.0

        func tieredCost(_ totalTokens: Int, base: Double?, above: Double?) -> Double {
            guard totalTokens > 0 else { return 0 }
            let tokens = Double(totalTokens)

            if tokens > threshold, let above {
                let below = min(tokens, threshold)
                let over = max(0, tokens - threshold)
                var cost = over * above
                if let base {
                    cost += below * base
                }
                return cost
            }

            if let base {
                return tokens * base
            }

            return 0
        }

        let input = tieredCost(tokens.inputTokens, base: pricing.inputCostPerToken, above: pricing.inputCostPerTokenAbove200kTokens)
        let output = tieredCost(tokens.outputTokens, base: pricing.outputCostPerToken, above: pricing.outputCostPerTokenAbove200kTokens)
        let cacheCreation = tieredCost(tokens.cacheCreationTokens, base: pricing.cacheCreationInputTokenCost, above: pricing.cacheCreationInputTokenCostAbove200kTokens)
        let cacheRead = tieredCost(tokens.cacheReadTokens, base: pricing.cacheReadInputTokenCost, above: pricing.cacheReadInputTokenCostAbove200kTokens)

        return input + output + cacheCreation + cacheRead
    }
}
