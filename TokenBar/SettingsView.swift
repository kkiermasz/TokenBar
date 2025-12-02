import SwiftUI

struct SettingsView: View {
    @AppStorage("launchAtLoginEnabled") private var launchAtLoginEnabled = false

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $launchAtLoginEnabled)
                .toggleStyle(.switch)
            Text("Start TokenBar automatically to capture usage without opening it manually.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(minWidth: 320)
        .onChange(of: launchAtLoginEnabled) { _, newValue in
            LaunchAtLoginManager.setEnabled(newValue)
        }
    }
}

#Preview {
    SettingsView()
}
