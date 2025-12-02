import Foundation
import Combine

final class UsageStore: ObservableObject {
    @Published private(set) var snapshot: UsageSnapshot?

    private let provider: UsageProviding

    init(provider: UsageProviding = SampleUsageProvider()) {
        self.provider = provider
        refresh()
    }

    func refresh() {
        snapshot = provider.fetchDailyUsage()
    }
}
