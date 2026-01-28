import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var appState: AppState

  var body: some View {
    Form {
      Section("Recording") {
        Stepper(
          value: Binding(
            get: { appState.settings.countdownSeconds },
            set: { appState.updateSettings(appState.settings.updating(countdownSeconds: $0)) }
          ),
          in: 0 ... 10
        ) {
          Text("Countdown: \(appState.settings.countdownSeconds)s")
        }
      }

      Section("Defaults") {
        Toggle("Camera enabled", isOn: Binding(
          get: { appState.settings.isCameraEnabled },
          set: { appState.updateSettings(appState.settings.updating(cameraEnabled: $0)) }
        ))
        Toggle("Microphone enabled", isOn: Binding(
          get: { appState.settings.isMicrophoneEnabled },
          set: { appState.updateSettings(appState.settings.updating(microphoneEnabled: $0)) }
        ))
        Toggle("System audio enabled", isOn: Binding(
          get: { appState.settings.isSystemAudioEnabled },
          set: { appState.updateSettings(appState.settings.updating(systemAudioEnabled: $0)) }
        ))
      }
    }
    .padding(20)
    .frame(width: 420)
  }
}

#Preview {
  SettingsView()
    .environmentObject(AppState.shared)
}
