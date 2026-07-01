import CaptureThisCore
import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var appState: AppState

  var body: some View {
    Form {
      Section {
        PermissionsSetupView(
          state: appState.permissionSetupState,
          style: .settings,
          action: appState.performPermissionSetupAction(for:)
        )
      } header: {
        HStack {
          Text("Permissions")
          Spacer()
          Button {
            appState.refreshPermissionSetupState()
          } label: {
            Label("Recheck", systemImage: "arrow.clockwise")
          }
          .buttonStyle(.borderless)
          .font(Theme.Typography.rowDetail)
          .help("Check permissions again")
        }
      } footer: {
        Text("CaptureThis needs these to record. Optional ones can stay off.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Section {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
          HStack {
            Text("Countdown")
            Spacer()
            Text("\(appState.settings.countdownSeconds)s")
              .foregroundStyle(.secondary)
              .monospacedDigit()
          }
          Slider(
            value: Binding(
              get: { Double(appState.settings.countdownSeconds) },
              set: { appState.updateSettings(appState.settings.updating(countdownSeconds: Int($0.rounded()))) }
            ),
            in: 0 ... 10,
            step: 1
          )
        }
      } header: {
        Text("Recording")
      } footer: {
        Text("Delay before capture begins after you hit Record.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Section {
        Toggle(isOn: cameraBinding) {
          Label("Camera overlay", systemImage: "camera")
        }
        Toggle(isOn: microphoneBinding) {
          Label("Microphone", systemImage: "mic")
        }
        Toggle(isOn: systemAudioBinding) {
          Label("System audio", systemImage: "speaker.wave.2")
        }
      } header: {
        Text("Capture Defaults")
      } footer: {
        Text("Applied to every new recording. Requires the matching permission above.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Section("Output") {
        Picker("Format", selection: Binding(
          get: { appState.settings.outputFormat },
          set: { appState.updateSettings(appState.settings.updating(outputFormat: $0)) }
        )) {
          ForEach(RecordingFileFormat.allCases) { format in
            Text(format.displayName).tag(format)
          }
        }

        Picker("Video Quality", selection: Binding(
          get: { appState.settings.recordingQuality },
          set: { appState.updateSettings(appState.settings.updating(recordingQuality: $0)) }
        )) {
          ForEach(RecordingQuality.allCases) { quality in
            Text(quality.displayName).tag(quality)
          }
        }

        Picker("GIF Quality", selection: Binding(
          get: { appState.settings.gifExportQuality },
          set: { appState.updateSettings(appState.settings.updating(gifExportQuality: $0)) }
        )) {
          ForEach(GIFExportQuality.allCases) { quality in
            Text(quality.displayName).tag(quality)
          }
        }
      }

      Section {
        Toggle(isOn: debugModeBinding) {
          Label("Debug mode", systemImage: "ladybug")
        }
      } header: {
        Text("Developer")
      } footer: {
        Text(String(localized: "settings.developer.footer"))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .frame(minWidth: 440, idealWidth: 480, maxWidth: 720, minHeight: 480, idealHeight: 600, maxHeight: .infinity)
    .onAppear {
      appState.refreshPermissionSetupState()
    }
  }

  private var cameraBinding: Binding<Bool> {
    Binding(
      get: { appState.settings.isCameraEnabled },
      set: { appState.updateSettings(appState.settings.updating(cameraEnabled: $0)) }
    )
  }

  private var microphoneBinding: Binding<Bool> {
    Binding(
      get: { appState.settings.isMicrophoneEnabled },
      set: { appState.updateSettings(appState.settings.updating(microphoneEnabled: $0)) }
    )
  }

  private var systemAudioBinding: Binding<Bool> {
    Binding(
      get: { appState.settings.isSystemAudioEnabled },
      set: { appState.updateSettings(appState.settings.updating(systemAudioEnabled: $0)) }
    )
  }

  private var debugModeBinding: Binding<Bool> {
    Binding(
      get: { appState.settings.isDebugModeEnabled },
      set: { appState.updateSettings(appState.settings.updating(debugModeEnabled: $0)) }
    )
  }
}

#Preview {
  SettingsView()
    .environmentObject(AppState.shared)
}
