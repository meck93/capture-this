import SwiftUI

struct SettingsView: View {
  var body: some View {
    Form {
      Section("General") {
        Text("Settings will appear here.")
      }
    }
    .padding(20)
    .frame(width: 420)
  }
}

#Preview {
  SettingsView()
}
