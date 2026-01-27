import SwiftUI

@main
struct CaptureThisApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    Settings {
      SettingsView()
    }
  }
}
