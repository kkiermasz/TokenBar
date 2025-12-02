import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var usageStore: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if let snapshot = usageStore.snapshot {
                ForEach(snapshot.summaries) { summary in
                    SummaryRow(summary: summary)
                        .padding(.vertical, 4)
                }

                Divider()
                Text("Last updated \(snapshot.updatedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Label("No usage yet", systemImage: "ellipsis.rectangle")
                        .font(.headline)
                    Text("Tracking starts once agent sessions run locally.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            }

            HStack {
                Button(action: usageStore.refresh) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r")

                Spacer()
            }
        }
        .padding(20)
        .frame(minWidth: 360)
        .onAppear {
            usageStore.refresh()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TokenBar")
                .font(.largeTitle.bold())
            if let snapshot = usageStore.snapshot {
                HStack(spacing: 12) {
                    Label("\(snapshot.totalTokens.formatted(.number)) tokens", systemImage: "number")
                    Label(currencyString(from: snapshot.totalCostUSD), systemImage: "creditcard")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            } else {
                Text("Daily totals will appear here once tracking starts.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
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

private struct SummaryRow: View {
    let summary: UsageSummary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(summary.agent.accentColor.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: summary.agent.symbolName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(summary.agent.accentColor)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(summary.agent.displayName)
                        .font(.headline)
                    Spacer()
                    Text(summary.estimatedCostUSD, format: .currency(code: "USD"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Label("\(summary.sessions) sessions", systemImage: "dot.radiowaves.left.and.right")
                    Label("\(summary.totalTokens.formatted(.number)) tokens", systemImage: "number")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(UsageStore())
}
