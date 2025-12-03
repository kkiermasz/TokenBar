import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var usageStore: UsageStore
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            UsageHeaderView(
                snapshot: usageStore.snapshot,
                isLoading: usageStore.isLoading,
                errorMessage: usageStore.errorMessage
            )

            Divider()

            if let snapshot = usageStore.snapshot {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(snapshot.periods) { period in
                        PeriodUsageRow(usage: period)
                    }
                    if !snapshot.modelBreakdownToday.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Today by model")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.primary)
                            ForEach(snapshot.modelBreakdownToday.prefix(5)) { model in
                                ModelUsageRow(usage: model)
                            }
                            if snapshot.modelBreakdownToday.count > 5 {
                                Text("Showing top 5 of \(snapshot.modelBreakdownToday.count)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    Text(weekStartDescription)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else if usageStore.isLoading {
                Label("Loading Claude usage…", systemImage: "sparkles")
                    .font(.caption)
                    .foregroundColor(.primary)
            } else {
                Label("Start a Claude session to see usage here.", systemImage: "ellipsis.rectangle")
                    .font(.caption)
                    .foregroundColor(.primary)
            }

            Divider()

            HStack(spacing: 12) {
                Label("Auto-refreshing every minute", systemImage: "arrow.clockwise.circle")
                    .font(.caption)
                    .foregroundColor(.primary)
                Spacer()
                if #available(macOS 14.0, *) {
                    Button {
                        NSApp.activate(ignoringOtherApps: true)
                        openSettings()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                } else {
                    SettingsLink {
                        Label("Settings", systemImage: "gearshape")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }

                Button(role: .destructive) {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit TokenBar", systemImage: "power")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(width: 320)
        .task {
            usageStore.refresh()
            usageStore.startAutoRefresh()
        }
        .onDisappear {
            usageStore.stopAutoRefresh()
        }
    }

    private var weekStartDescription: String {
        let index = environment.calendar.firstWeekday - 1
        let symbol = environment.calendar.weekdaySymbols.indices.contains(index) ? environment.calendar.weekdaySymbols[index] : "Sunday"
        return "Weeks start on \(symbol)"
    }
}
