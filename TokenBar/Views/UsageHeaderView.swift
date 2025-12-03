import SwiftUI

struct UsageHeaderView: View {
    let snapshot: UsageSnapshot?
    let isLoading: Bool
    let errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Claude usage")
                    .font(.headline)
                    .foregroundColor(.primary)
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            } else if let snapshot {
                let metrics = snapshot.todayMetrics ?? snapshot.periods.first?.metrics
                HStack(spacing: 8) {
                    Label("\((metrics?.totalTokens ?? 0).formatted(.number)) tokens", systemImage: "chart.bar.fill")
                    Label(CurrencyFormatter.usd(from: metrics?.costUSD ?? .zero), systemImage: "creditcard.fill")
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
            } else {
                Text(isLoading ? "Reading Claude usage files…" : "No Claude usage recorded yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
