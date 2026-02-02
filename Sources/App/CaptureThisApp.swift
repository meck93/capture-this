import CaptureThisCore
import SwiftUI

@main
struct CaptureThisApp: App {
  @StateObject private var appState = AppState.shared
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    Settings {
      SettingsView()
        .environmentObject(appState)
        .onAppear { NSApp.activate(ignoringOtherApps: true) }
    }
  }
}
