import SwiftUI
import AppKit

struct MenuBarView: View {
    @Environment(\.claudeUsageService) private var usageService: ClaudeUsageServicing

    var body: some View {
        TabView {
            MenuBarUsageContentView(source: .claude, service: usageService)
                .tabItem {
                    Label(UsageSource.claude.title, systemImage: UsageSource.claude.icon)
                }

            MenuBarUsageContentView(source: .codex, service: usageService)
                .tabItem {
                    Label(UsageSource.codex.title, systemImage: UsageSource.codex.icon)
                }
        }
        .background(Color.clear)
        .padding(12)
        .frame(width: 320)
    }
}
