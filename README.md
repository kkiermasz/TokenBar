# TokenBar

Menu bar app for macOS that shows your local Claude Code usage (tokens, sessions, and estimated cost) without sending any data off-device.

![Menu bar screenshot](Screenshot%202025-12-03%20at%2014.07.34.png)

## Features
- Live Claude usage pulled from local JSONL telemetry (`~/.config/claude/projects` and `~/.claude/projects`)
- Aggregates tokens, sessions, and USD estimates for today/this week/this month with top models highlighted
- Auto-refreshes every minute and keeps the app dockless; quick quit and Settings from the menu bar
- Launch at login toggle so tracking starts automatically
- Pricing based on LiteLLM's public model dataset with tiered Anthropic rates

## Requirements
- macOS 14.0 or newer
- Xcode 15 or newer (Swift 5.9)
- Claude Code telemetry files on disk (the app only reads local files; Codex sessions are intentionally ignored in the menu bar to avoid mixing sources)
- Optional: network access to fetch the latest model pricing; usage still works offline but costs may show as $0

## Install
Build from source (unsigned):

1) Clone the repo and open it in Xcode: `open TokenBar.xcodeproj`
2) Select the `TokenBar` scheme and run it; the app will appear in the menu bar
3) For a Release build from the CLI:
```bash
xcodebuild -scheme TokenBar -configuration Release -destination 'platform=macOS'
```

GitHub Actions archives the app on tags/releases (`.github/workflows/archive-macos.yml`) and produces an unsigned zip you can download from workflow artifacts.

## Using TokenBar
- Start Claude sessions as usual; TokenBar reads the JSONL files they produce.
- Default search paths: `~/.config/claude/projects` and `~/.claude/projects`.
- Override with `CLAUDE_CONFIG_DIR` (comma-separated for multiple roots), e.g.:
```bash
export CLAUDE_CONFIG_DIR="$HOME/.config/claude,$HOME/dev/custom-claude"
```
- The menu shows totals for today/week/month and the top 5 models used today. Totals auto-refresh every 60 seconds while the menu is open.
- Launch at login can be toggled in Settings (macOS 13+).

## Privacy and networking
- Usage parsing happens locally; no usage or session data leaves your machine.
- Pricing is fetched from the public LiteLLM pricing JSON on GitHub to estimate USD costs; if the fetch fails, TokenBar falls back to zero-cost estimates.

## Development
- Build (Debug): `xcodebuild -scheme TokenBar -configuration Debug -destination 'platform=macOS'`
- Tests: `swift test` (or `xcodebuild test -scheme TokenBarTests -destination 'platform=macOS'`)
- Optional prettier output: pipe builds/tests through `xcbeautify`
- Style: 4-space indentation, 120-col soft wrap, trailing commas in multi-line literals, mark classes `final` where possible

## Troubleshooting
- No usage showing: verify Claude is writing JSONL files to the paths above or set `CLAUDE_CONFIG_DIR` to the correct location.
- Costs are $0: check network access for the LiteLLM pricing fetch or run again later; usage totals will still be correct.
- Launch at login unavailable: ensure you're on macOS 13+ and granting the toggle permission.

## Contributing
- Please open an issue or PR with a short description of the change and testing performed.
- Run the Debug build and `swift test` before submitting; include screenshots for UI changes.

## License
No license file is present yet. Add an open-source license (e.g., MIT or Apache-2.0) before distributing builds.
