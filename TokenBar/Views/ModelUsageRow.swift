import SwiftUI

struct ModelUsageRow: View {
    let usage: ModelUsage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(usage.modelName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(usage.totalTokens.formatted(.number)) tokens · in \(usage.inputTokens.formatted(.number)), out \(usage.outputTokens.formatted(.number))")
                    .font(.caption2)
                    .foregroundColor(.primary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyFormatter.usd(from: usage.costUSD))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.primary)
                if usage.cacheTokens > 0 {
                    Text("cache \(usage.cacheTokens.formatted(.number))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}
