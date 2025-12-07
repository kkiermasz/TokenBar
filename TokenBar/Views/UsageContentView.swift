import SwiftUI

struct UsageContentView: View {
    let source: UsageSource
    @Environment(\.claudeUsageService) private var usageService: ClaudeUsageServicing
    @StateObject private var usageStore: UsageStore

    init(source: UsageSource, service: ClaudeUsageServicing) {
        self.source = source
        _usageStore = StateObject(wrappedValue: UsageStore(service: service))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            UsageHeaderView(
                snapshot: usageStore.snapshot,
                isLoading: usageStore.isLoading,
                errorMessage: usageStore.errorMessage
            )

            Divider()

            if let snapshot = usageStore.snapshot {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(snapshot.periods) { usage in
                        PeriodUsageRow(usage: usage)
                    }
                }
            } else if usageStore.isLoading {
                Label("Loading \(source.title) usage…", systemImage: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Label("Start a \(source.title) session to see usage.", systemImage: "ellipsis.rectangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .task {
            usageStore.selectedSource = source
            usageStore.refresh()
            usageStore.startAutoRefresh()
        }
        .onDisappear {
            usageStore.stopAutoRefresh()
        }
    }
}
