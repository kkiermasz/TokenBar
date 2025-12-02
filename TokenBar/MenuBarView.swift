import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject private var usageStore: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TokenBar")
                        .font(.headline)
                    if let snapshot = usageStore.snapshot {
                        Text("\(snapshot.totalTokens.formatted(.number)) tokens · \(currencyString(from: snapshot.totalCostUSD))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Waiting for first session")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button(action: usageStore.refresh) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh usage")
            }

            if let snapshot = usageStore.snapshot {
                ForEach(snapshot.summaries) { summary in
                    HStack {
                        Image(systemName: summary.agent.symbolName)
                            .foregroundStyle(summary.agent.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(summary.agent.displayName)
                            Text("\(summary.sessions) sessions · \(summary.totalTokens.formatted(.number)) tokens")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(summary.estimatedCostUSD, format: .currency(code: "USD"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()
                Text("Updated \(snapshot.updatedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Start a Codex or Claude session to see live totals.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()
            VStack(alignment: .leading, spacing: 8) {
                if #available(macOS 14.0, *) {
                    SettingsLink {
                        Label("Open Settings…", systemImage: "gearshape")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                } else {
                    Label("Open Settings…", systemImage: "gearshape")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .help("Requires macOS 14+ to open Settings from the menu bar")
                }
            }

            Divider()
            Button(role: .destructive) {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit TokenBar", systemImage: "power")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 280)
        .onAppear {
            usageStore.refresh()
        }
    }

    private func currencyString(from decimal: Decimal) -> String {
        let number = NSDecimalNumber(decimal: decimal)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 4
        return formatter.string(from: number) ?? "$0.00"
    }
}

#Preview {
    MenuBarView()
        .environmentObject(UsageStore())
}
