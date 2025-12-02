import Foundation
import OSLog

#if canImport(ServiceManagement)
import ServiceManagement
#endif

enum LaunchAtLoginManager {
    private static let logger = Logger(subsystem: "app.tokenbar", category: "launch")

    static func setEnabled(_ enabled: Bool) {
        #if canImport(ServiceManagement)
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                logger.error("Failed to update launch at login: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            logger.warning("Launch at login requires macOS 13.0+")
        }
        #else
        logger.error("ServiceManagement unavailable; cannot set launch at login")
        #endif
    }
}
