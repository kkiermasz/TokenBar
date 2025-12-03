import SwiftUI

struct PeriodUsageRow: View {
    let usage: PeriodUsage

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(usage.period.accentColor.opacity(0.25))
                    .frame(width: 36, height: 36)
                Image(systemName: usage.period.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(usage.period.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(usage.period.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("\(usage.metrics.sessionCount) sessions · \(usage.metrics.totalTokens.formatted(.number)) tokens")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.primary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyFormatter.usd(from: usage.metrics.costUSD))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.primary)
                Text("in \(usage.metrics.inputTokens.formatted(.number)) / out \(usage.metrics.outputTokens.formatted(.number))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}
