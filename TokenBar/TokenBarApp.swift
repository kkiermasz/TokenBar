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
    @StateObject private var usageStore = UsageStore()

    init() {
        // Keep app dockless; show only the menu bar extra.
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra("TokenBar", systemImage: "chart.bar.xaxis") {
            MenuBarView()
                .environmentObject(usageStore)
        }

        Settings {
            SettingsView()
        }
    }
}
