//
//  TokenBarApp.swift
//  TokenBar
//
//  Created by Jakub Kiermasz on 02/12/2025.
//

import SwiftUI
import AppKit

@main
struct TokenBarApp: App {
    private let usageService: ClaudeUsageServicing
    private let calendar: Calendar

    init() {
        let usageService = ClaudeUsageService()
        let calendar = Calendar.autoupdatingCurrent
        self.usageService = usageService
        self.calendar = calendar
        // Keep app dockless; show only the menu bar extra.
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra("TokenBar", systemImage: "chart.bar.xaxis") {
            MenuBarView()
                .environment(\.claudeUsageService, usageService)
                .environment(\.calendar, calendar)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}
