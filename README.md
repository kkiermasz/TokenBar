# TokenBar

> Track your Claude AI usage and costs right from your macOS menu bar

<p align="center">
  <img src="Screenshot 2025-12-03 at 14.07.34.png" alt="TokenBar Menu" width="400">
</p>

TokenBar is a lightweight macOS menu bar application that helps you monitor token usage and costs for Claude Code and Codex CLI. It reads telemetry data locally from your machine and displays real-time statistics without sending any data to external servers.

## Features

- **Real-time Usage Tracking** - Monitor token consumption across all your Claude sessions
- **Cost Estimation** - Automatic cost calculation using up-to-date LiteLLM pricing data
- **Time-based Breakdown** - View usage statistics for today, this week, and this month
- **Model-level Details** - See which Claude models you're using most (Sonnet, Opus, Haiku)
- **Privacy-first** - All data processing happens locally on your Mac
- **Auto-refresh** - Updates every minute to keep your stats current
- **Launch at Login** - Optional system integration for persistent monitoring

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon or Intel Mac
- Claude Code or Codex CLI installed

## Installation

### Download

1. Download the latest release from the [Releases](https://github.com/kkiermasz/TokenBar/releases) page
2. Open the downloaded `.dmg` file
3. Drag TokenBar to your Applications folder
4. Launch TokenBar from Applications

### Build from Source

```bash
git clone https://github.com/kkiermasz/TokenBar.git
cd TokenBar
xcodebuild -scheme TokenBar -configuration Release -destination 'platform=macOS'
```

For development builds with prettier output:

```bash
xcodebuild -scheme TokenBar -configuration Debug -destination 'platform=macOS' | xcbeautify
```

## Usage

TokenBar runs silently in your menu bar, indicated by a chart icon. Click the icon to view:

- **Total tokens** consumed across all sessions
- **Estimated costs** in USD based on current pricing
- **Session counts** for each time period
- **Input/output token breakdown** for detailed analysis
- **Per-model statistics** showing usage by Claude model version

### Data Sources

TokenBar automatically discovers and reads telemetry from:

- `~/.claude/projects/` (Claude Code)
- `~/.config/claude/projects/` (Claude Code alternative location)

You can override the data directory using the `CLAUDE_CONFIG_DIR` environment variable (supports comma-separated paths for multiple sources).

### Settings

Access settings through the menu:

- **Launch at Login** - Start TokenBar automatically when you log in
- **Week Start Day** - Defaults to Sunday to match Claude's ccusage tool

## How It Works

TokenBar uses a protocol-oriented architecture with clear separation of concerns:

1. **Discovery** - Scans your Claude data directories for JSONL telemetry files
2. **Parsing** - Streams and processes each file, deduplicating entries by message ID
3. **Aggregation** - Groups usage by calendar periods (today/week/month)
4. **Pricing** - Fetches model pricing from LiteLLM's public pricing database
5. **Display** - Updates the menu bar view with calculated statistics

All processing happens locally. The only network request is fetching the LiteLLM pricing data (cached per session).

## Development

### Project Structure

```
TokenBar/
├── TokenBarApp.swift           # App entry point
├── Services/
│   ├── ClaudeUsageService.swift
│   ├── ClaudePricingService.swift
│   └── AppEnvironment.swift
├── Stores/
│   └── UsageStore.swift
├── Models/
│   └── UsageModels.swift
├── Views/
│   ├── MenuBarView.swift
│   └── ContentView.swift
└── Utilities/
    └── CurrencyFormatter.swift
```

### Running Tests

```bash
xcodebuild test -scheme TokenBarTests -destination 'platform=macOS'
```

### Architecture

TokenBar follows protocol-oriented design principles:

- **`ClaudeUsageServicing`** - Protocol for usage data fetching and aggregation
- **`ClaudePricingProviding`** - Protocol for cost calculation
- **Dependency Injection** - All services injected through initializers for testability
- **SwiftUI + Combine** - Modern reactive UI with `@StateObject` and `ObservableObject`

See [CLAUDE.md](CLAUDE.md) for detailed development guidelines.

## Privacy & Security

- **No data collection** - TokenBar never sends your usage data anywhere
- **Local processing only** - All calculations happen on your Mac
- **Read-only access** - Only reads telemetry files, never modifies them
- **No telemetry** - TokenBar itself doesn't track or log your usage

The only external network request is fetching model pricing from LiteLLM's public GitHub repository.

## FAQ

**Q: Does TokenBar work with the Claude web interface?**
A: No, TokenBar only tracks Claude Code (CLI) and Codex CLI usage that generates local telemetry files.

**Q: Are the cost estimates accurate?**
A: Costs are estimates based on LiteLLM's pricing data, which includes Claude's 200k token tiered pricing. Actual costs may vary based on your Anthropic billing plan.

**Q: Why are my costs different from Anthropic's dashboard?**
A: TokenBar calculates costs based on token usage in local telemetry. Some sessions may include cached tokens or have different pricing depending on your plan.

**Q: Can I export my usage data?**
A: Currently, TokenBar is view-only. You can access raw telemetry files directly from `~/.claude/projects/` if you need to export data.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

### Development Guidelines

- Follow Swift conventions (4-space indentation)
- Add tests for new functionality
- Keep views thin - push logic into services
- Update CLAUDE.md if adding new architecture patterns

## Acknowledgments

- Pricing data provided by [LiteLLM](https://github.com/BerriAI/litellm)
- Built with SwiftUI for macOS 14+
- Inspired by Claude Code's `ccusage` command

## License

TokenBar is available under the MIT License. See the LICENSE file for more info.

---

**Note:** TokenBar is an independent project and is not officially affiliated with Anthropic or Claude AI.
