# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TokenBar is a macOS menu bar app that tracks Claude Code and Codex CLI usage locally. It displays token consumption, session counts, and cost estimates by reading JSONL telemetry files from `~/.claude/projects/` and `~/.config/claude/projects/`.

## Build and Test Commands

**Building:**

```bash
# Build from Xcode (recommended)
xcodebuild -scheme TokenBar -configuration Debug -destination 'platform=macOS'

# Build with prettier output
xcodebuild -scheme TokenBar -configuration Debug -destination 'platform=macOS' | xcbeautify

# Open in Xcode
open TokenBar.xcodeproj
```

**Testing:**

```bash
# Run tests
xcodebuild test -scheme TokenBarTests -destination 'platform=macOS'

# Run tests with prettier output
xcodebuild test -scheme TokenBarTests -destination 'platform=macOS' | xcbeautify
```

**Requirements:**

- Xcode 15+ with Swift 5.9+
- macOS deployment target: macOS 14.0+

## Architecture Overview

TokenBar follows a protocol-oriented architecture with clear separation of concerns:

**Core Data Flow:**

1. `ClaudeUsageService` discovers and parses JSONL files from Claude data directories
2. Aggregates token usage and calculates costs using `ClaudePricingService`
3. `UsageStore` manages state and auto-refresh logic
4. SwiftUI views (`MenuBarView`, `ContentView`) display the data

**Key Protocols:**

- `ClaudeUsageServicing` - Usage data fetching and aggregation
- `ClaudePricingProviding` - Cost calculation using LiteLLM pricing data

**Module Organization:**

```
TokenBar/
├── TokenBarApp.swift           # App entry point (MenuBarExtra)
├── Services/
│   ├── EnvironmentValues+Extensions.swift # SwiftUI environment keys for services
│   ├── ClaudeUsageService.swift # JSONL parsing and aggregation
│   ├── ClaudePricingService.swift # LiteLLM pricing integration
│   └── LaunchAtLoginManager.swift
├── Stores/
│   └── UsageStore.swift        # ObservableObject state management
├── Models/
│   └── UsageModels.swift       # Data structures (UsageSnapshot, ModelUsage, etc.)
├── Views/
│   ├── MenuBarView.swift       # Menu bar dropdown
│   ├── UsageHeaderView.swift
│   ├── PeriodUsageRow.swift
│   └── ModelUsageRow.swift
├── Utilities/
│   └── CurrencyFormatter.swift
├── ContentView.swift           # Main content view
└── SettingsView.swift          # Settings window
```

**Data Sources:**

- **Claude Code**: Reads from `~/.claude/projects/` and `~/.config/claude/projects/`
- **Codex CLI**: Can read from `~/.codex/sessions/` (support exists but not used in menu bar to avoid mixing sources)
- **Environment Variable**: Supports `CLAUDE_CONFIG_DIR` for custom paths (comma-separated)

**Pricing Integration:**

- Fetches pricing from LiteLLM's `model_prices_and_context_window.json` on GitHub
- Implements 200k token tiered pricing for Anthropic models
- Respects pre-calculated `costUSD` from JSONL when available (auto mode)
- Caches pricing data per session to minimize network requests

**Key Implementation Details:**

- Uses `FileHandle.AsyncBytes` for streaming JSONL parsing
- Deduplicates entries by `message.id + requestId` hash
- Aggregates by calendar periods (today/week/month) using `Calendar` API
- Calendar configured with `firstWeekday = 1` (Sunday) to match ccusage behavior

## Development Workflow

**Code Style:**

- 4-space indentation (standard Swift convention)
- 120-character soft wrap
- Trailing commas in multi-line collections
- Mark classes `final` where appropriate
- Use `Logger` from `OSLog` for logging (never `NSLog`)
- Never use `NSError` - create custom error enums conforming to `Error` protocol instead

**Naming Conventions:**

- Views end with `View` (e.g., `MenuBarView`)
- Services end with `Service` (e.g., `ClaudeUsageService`)
- Stores end with `Store` (e.g., `UsageStore`)
- Protocols end with `-ing` suffix (e.g., `ClaudeUsageServicing`)
- Domain language: `UsageSnapshot`, `ModelUsage`, `TokenUsage`, `PeriodUsage`

**Architecture Principles:**

- Protocol-oriented design for testability
- Inject dependencies through initializers (avoid singletons)
- Prefer value types (`struct`) for models and SwiftUI views
- Keep view logic thin - push calculations into services
- All business logic should be testable without UI
- **Dependency Injection:** Inject each service independently into SwiftUI environment rather than bundling them in a container class. Use custom `EnvironmentKey` extensions for each service (see `EnvironmentValues+Extensions.swift`). This provides cleaner, more granular dependency injection and makes it clear which views depend on which services.

## Testing Guidelines

**Test Structure:**

- Use XCTest framework
- Test files named after the code they test (e.g., `ClaudeUsageServiceTests.swift`)
- Test methods should read as expectations: `testCostTotalsRoundToCents()`

**Coverage Focus:**

- Cost calculation logic and 200k tiered pricing boundaries
- JSONL parsing and deduplication
- Date/calendar aggregation logic
- Token counting and accumulation

**Test Data:**

- Use current Claude 4 models in tests (`claude-sonnet-4-20250514`, `claude-opus-4-20250514`)
- Create fixture JSONL files for various scenarios
- Mock network requests for LiteLLM pricing data

## Environment Variables

- `CLAUDE_CONFIG_DIR` - Override Claude data directory (supports comma-separated multiple paths)
- `CODEX_HOME` - Override Codex data directory (default: `~/.codex`)

## Git Commit and PR Conventions

**Commit Messages:**

- Imperative mood, short (50 chars), scoped to one concern
- Examples:
  - `Add session ledger model`
  - `Wire cost summary to menu bar`
  - `Fix token deduplication logic`

**Pull Requests:**

- Concise description of the change
- Include testing performed
- Screenshots/GIFs for UI changes (menu bar states)
- Must pass build before merging: `xcodebuild -scheme TokenBar -configuration Debug`

## Security Notes

- Never commit API keys or secrets
- All telemetry is processed locally - no data leaves the device
- Pricing data fetched from public GitHub URL (LiteLLM)
- User consent required for any future cloud features

## Related Documentation

- `/docs/ccusage-analysis.md` - Analysis of ccusage implementation (reference for token accounting)
- `/agents.json` - Codex-specific repository instructions
