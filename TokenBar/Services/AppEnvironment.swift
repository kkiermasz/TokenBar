import Combine
import Foundation

final class AppEnvironment: ObservableObject {
    let usageService: ClaudeUsageServicing
    let calendar: Calendar
    let objectWillChange = ObservableObjectPublisher()

    init(
        usageService: ClaudeUsageServicing = ClaudeUsageService(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.usageService = usageService
        self.calendar = calendar
    }
}
