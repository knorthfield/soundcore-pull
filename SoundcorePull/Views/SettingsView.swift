import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $launchAtLogin)
            Text("Keeps the recorder syncing without opening the app by hand.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .onAppear { launchAtLogin = SMAppService.mainApp.status == .enabled }
        .onChange(of: launchAtLogin) { _, enabled in
            guard enabled != (SMAppService.mainApp.status == .enabled) else { return }
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
                launchAtLogin = !enabled
            }
        }
    }
}
