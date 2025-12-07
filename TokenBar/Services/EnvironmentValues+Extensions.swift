import Foundation
import SwiftUI

// Environment keys for individual services
private struct ClaudeUsageServiceKey: EnvironmentKey {
    static let defaultValue: ClaudeUsageServicing = ClaudeUsageService()
}

private struct CalendarKey: EnvironmentKey {
    static let defaultValue: Calendar = .autoupdatingCurrent
}

extension EnvironmentValues {
    var claudeUsageService: ClaudeUsageServicing {
        get { self[ClaudeUsageServiceKey.self] }
        set { self[ClaudeUsageServiceKey.self] = newValue }
    }

    var calendar: Calendar {
        get { self[CalendarKey.self] }
        set { self[CalendarKey.self] = newValue }
    }
}
