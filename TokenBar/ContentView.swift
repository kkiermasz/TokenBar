import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var usageStore: UsageStore

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
                Label("Loading Claude usage…", systemImage: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Label("Start a Claude session to see usage.", systemImage: "ellipsis.rectangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(minWidth: 360)
        .task {
            usageStore.refresh()
            usageStore.startAutoRefresh()
        }
        .onDisappear {
            usageStore.stopAutoRefresh()
        }
    }
}
