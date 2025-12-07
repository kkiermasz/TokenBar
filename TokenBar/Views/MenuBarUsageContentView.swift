import SwiftUI

struct MenuBarUsageContentView: View {
    let source: UsageSource
    @Environment(\.calendar) private var calendar
    @StateObject private var usageStore: UsageStore
    @Environment(\.openSettings) private var openSettings

    init(source: UsageSource, service: ClaudeUsageServicing) {
        self.source = source
        _usageStore = StateObject(wrappedValue: UsageStore(service: service))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("\(source.title) usage")
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
                Label("Loading \(source.title) usage…", systemImage: source.icon)
                    .font(.caption)
                    .foregroundColor(.primary)
            } else {
                Label("Start a \(source.title) session to see usage here.", systemImage: "ellipsis.rectangle")
                    .font(.caption)
                    .foregroundColor(.primary)
            }

            Divider()

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Auto-refreshing every minute", systemImage: "arrow.clockwise.circle")
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
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
                        Label("Quit", systemImage: "power")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 8)
        .task {
            usageStore.selectedSource = source
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
