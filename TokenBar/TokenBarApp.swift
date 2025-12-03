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
    @StateObject private var environment: AppEnvironment
    @StateObject private var usageStore: UsageStore

    init() {
        let environment = AppEnvironment()
        _environment = StateObject(wrappedValue: environment)
        _usageStore = StateObject(wrappedValue: UsageStore(service: environment.usageService, calendar: environment.calendar))
        // Keep app dockless; show only the menu bar extra.
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra("TokenBar", systemImage: "chart.bar.xaxis") {
            MenuBarView()
                .environmentObject(environment)
                .environmentObject(usageStore)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(environment)
        }
    }
}
