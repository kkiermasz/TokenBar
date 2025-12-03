# ccusage token usage and pricing analysis

Notes from reviewing [ryoppippi/ccusage](https://github.com/ryoppippi/ccusage) to understand how it observes Claude Code token usage and calculates pricing, plus a plan to bring equivalent behavior into TokenBar.

## How ccusage ingests Claude Code usage
- Scans local Claude data dirs, preferring `CLAUDE_CONFIG_DIR` (comma-separated), otherwise `~/.config/claude/projects/` then `~/.claude/projects/` (`getClaudePaths` in `apps/ccusage/src/data-loader.ts`).
- Reads every `*.jsonl` file under `projects/**` with a streaming line reader to avoid loading whole files. Files are sorted by earliest timestamp so older sessions are processed first.
- Each JSONL line must match `usageDataSchema`: `timestamp`, optional `version`, `sessionId`, `requestId`, `message.id`, `message.model`, `message.usage` fields (`input_tokens`, `output_tokens`, optional `cache_creation_input_tokens`, `cache_read_input_tokens`), optional `costUSD`, and `isApiErrorMessage`.
- Deduplicates entries by `message.id + requestId` hash; skips `<synthetic>` model rows. Extracts project name from the path (`projects/{project}/{sessionId}.jsonl`) to support per-project grouping.
- Cost per entry is chosen by mode (`calculateCostForEntry`):
  - `display`: always use `costUSD` (missing → 0).
  - `calculate`: ignore `costUSD`, compute from tokens + pricing.
  - `auto` (default): use `costUSD` when present; otherwise compute from tokens + pricing.
- Aggregations: daily/monthly/weekly bucketed by formatted date; session view groups by `{projectPath}/{sessionId}`; 5-hour billing windows are built via `identifySessionBlocks` with gap detection. All aggregations accumulate input/output/cache creation/cache read tokens, sum cost, and emit per-model breakdowns sorted by cost.
- Context usage helper (`calculateContextTokens`) re-reads transcript JSONL to grab the latest assistant message usage, adds cache tokens to input, and compares against model `max_input_tokens` from pricing (fallback 200k) to produce a percent-of-context indicator.

## Pricing data and cost math
- Pricing comes from LiteLLM’s `model_prices_and_context_window.json` via `LiteLLMPricingFetcher` (`packages/internal/src/pricing.ts`). Default provider prefixes cover Anthropic/Claude, OpenAI/Azure, and OpenRouter variants so model name mismatches are resolved before lookup; fuzzy contains matching is a final fallback.
- Offline cache: a build-time macro (`apps/ccusage/src/_macro.ts`) fetches LiteLLM pricing and filters to `claude-*` models. `PricingFetcher` wraps `LiteLLMPricingFetcher` to inject that snapshot when `offline` is true or when live fetch fails, and logs through the shared logger.
- Fetch behavior: caches pricing in-memory; on first use in online mode it fetches the JSON from GitHub, validates via `valibot`, stores `Map<model, pricing>`, and falls back to the offline snapshot on errors. `getModelContextLimit` reads `max_input_tokens` from the same data.
- Cost calculation (`calculateCostFromPricing`): sums four token types (input, output, cache creation, cache read) applying tiered pricing for 1M-context models. Uses a 200k token threshold—tokens above it use `*_above_200k_tokens` rates, tokens below use base rates; if a base rate is missing it only charges tokens above the threshold. No rounding is applied during math; formatting happens later in UI helpers.
- Debug tooling (`apps/ccusage/src/debug.ts`) can compare stored `costUSD` vs calculated cost, with a 0.1% tolerance, to surface pricing mismatches by model/version.

## Development plan for TokenBar
- Build a telemetry ingestion service (`Sources/Telemetry`) that mirrors ccusage’s JSONL parsing: resolve Claude data roots (env override + defaults), stream lines with validation, deduplicate on message/request IDs, skip `<synthetic>`, and surface project/session metadata for grouping.
- Add a pricing service backed by LiteLLM’s pricing JSON: fetch-and-cache online data with an embedded Claude snapshot for offline use, include provider-prefix candidates and fuzzy lookup, and expose context limits and cost calculation.
- Implement the 200k tiered pricing math for Anthropic models (input/output/cache creation/cache read tokens) plus a cost-mode switch (auto/calculate/display) so we can respect Claude’s own cost fields when present.
- Create aggregation utilities for daily/monthly/weekly buckets, per-session summaries, and 5-hour billing windows with gap detection; return per-model breakdowns and totals suitable for headless tests.
- Surface a context-usage helper that reads transcript JSONL to compute percentage of context used per session/model, falling back gracefully when metadata is missing.
- Add targeted tests: schema validation, deduping, pricing lookup fallbacks, tiered boundary cases (200k +/- 1), cache token handling, and cost-mode selection. Keep math in `Sources/Telemetry` and pricing in `Sources/Telemetry` or `Sources/Services` so menu bar UI stays thin.
