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
        var workingCalendar = calendar
        workingCalendar.firstWeekday = 1 // Sunday, mirrors ccusage defaults

        self.usageService = usageService
        self.calendar = workingCalendar
    }
}
