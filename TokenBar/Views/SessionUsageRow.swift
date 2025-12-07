import SwiftUI

struct SessionUsageRow: View {
    let usage: SessionUsage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(usage.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(usage.totalTokens.formatted(.number)) tokens · \(usage.requestCount) requests")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyFormatter.usd(from: usage.costUSD))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.primary)
                Text("in \(usage.inputTokens.formatted(.number)) / out \(usage.outputTokens.formatted(.number))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}
