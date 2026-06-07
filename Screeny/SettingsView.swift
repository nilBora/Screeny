import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettings.defaultSaveFormatKey) private var defaultFormat = SaveFormat.png.rawValue
    @State private var hasPermission = false

    var body: some View {
        Form {
            LabeledContent("Screen recording") {
                permissionStatus
            }

            Picker("Default save format", selection: $defaultFormat) {
                ForEach(SaveFormat.allCases, id: \.rawValue) { format in
                    Text(format.displayName).tag(format.rawValue)
                }
            }
            .pickerStyle(.menu)
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { refreshPermission() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermission()
        }
    }

    @ViewBuilder
    private var permissionStatus: some View {
        if hasPermission {
            Label("Granted", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            HStack(spacing: 8) {
                Label("Not granted", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Button("Open System Settings", action: openSystemSettings)
                    .buttonStyle(.link)
            }
        }
    }

    private func refreshPermission() {
        hasPermission = CGPreflightScreenCaptureAccess()
    }

    private func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
