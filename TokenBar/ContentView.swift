import SwiftUI

struct ContentView: View {
    @Environment(\.claudeUsageService) private var usageService: ClaudeUsageServicing

    var body: some View {
        TabView {
            UsageContentView(source: .claude, service: usageService)
                .tabItem {
                    Label(UsageSource.claude.title, systemImage: UsageSource.claude.icon)
                }

            UsageContentView(source: .codex, service: usageService)
                .tabItem {
                    Label(UsageSource.codex.title, systemImage: UsageSource.codex.icon)
                }
        }
        .background(Color.clear)
        .padding(20)
        .frame(minWidth: 360)
    }
}
