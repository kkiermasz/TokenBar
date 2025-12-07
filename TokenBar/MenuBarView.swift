import SwiftUI
import AppKit

struct MenuBarView: View {
    @Environment(\.calendar) private var calendar
    @EnvironmentObject private var usageStore: UsageStore
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("Claude usage")
                    .font(.headline)
                    .foregroundColor(.primary)
                if usageStore.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

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

                            if let metrics = snapshot.todayMetrics {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Label("\(metrics.totalTokens.formatted(.number)) tokens", systemImage: "chart.bar.fill")
                                        Label(CurrencyFormatter.usd(from: metrics.costUSD), systemImage: "creditcard.fill")
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.primary)
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color(nsColor: .controlBackgroundColor))
                                            .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
                                    )
                                    Text("Updated \(snapshot.updatedAt.formatted(date: .omitted, time: .shortened))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }

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
                    if !snapshot.sessionBreakdownToday.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Today by session")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.primary)
                            ScrollView(.vertical, showsIndicators: true) {
                                VStack(spacing: 6) {
                                    ForEach(snapshot.sessionBreakdownToday) { session in
                                        SessionUsageRow(usage: session)
                                    }
                                }
                                .padding(.vertical, 1)
                            }
                            .frame(height: min(CGFloat(snapshot.sessionBreakdownToday.count) * 50, 200))
                            if snapshot.sessionBreakdownToday.count > 1 {
                                Text("\(snapshot.sessionBreakdownToday.count) sessions today")
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
        let index = calendar.firstWeekday - 1
        let symbol = calendar.weekdaySymbols.indices.contains(index) ? calendar.weekdaySymbols[index] : "Sunday"
        return "Weeks start on \(symbol)"
    }
}
