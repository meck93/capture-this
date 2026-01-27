import SwiftUI

struct MenuBarView: View {
  @State private var isCameraEnabled = true
  @State private var isMicrophoneEnabled = true
  @State private var isSystemAudioEnabled = true

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("CaptureThis")
        .font(.headline)

      Picker("Source", selection: .constant("Display")) {
        Text("Display").tag("Display")
        Text("Window").tag("Window")
        Text("Application").tag("Application")
      }
      .pickerStyle(.segmented)

      Toggle("Camera", isOn: $isCameraEnabled)
      Toggle("Microphone", isOn: $isMicrophoneEnabled)
      Toggle("System Audio", isOn: $isSystemAudioEnabled)

      Button("Record") {
        // Placeholder for recording start
      }
      .keyboardShortcut(.defaultAction)

      Divider()

      Text("Recent Recordings")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      Text("No recordings yet")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(12)
    .frame(width: 300)
  }
}

#Preview {
  MenuBarView()
}
