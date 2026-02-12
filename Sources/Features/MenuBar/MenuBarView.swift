import AppKit
import CaptureThisCore
import SwiftUI

struct MenuBarView: View {
  @EnvironmentObject private var appState: AppState

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("CaptureThis")
        .font(.headline)

      Picker("Source", selection: $appState.captureSource) {
        ForEach(CaptureSource.allCases) { source in
          Text(source.displayName).tag(source)
        }
      }
      .pickerStyle(.segmented)

      Button(recordButtonTitle) {
        appState.startOrStopRecording()
      }
      .keyboardShortcut(.defaultAction)
      .disabled(isRecordButtonDisabled)

      if case let .recording(isPaused) = appState.recordingState {
        Button(isPaused ? "Resume" : "Pause") {
          appState.togglePauseResume()
        }
      }

      if let errorMessage = appState.errorMessage {
        Text(errorMessage)
          .font(.caption)
          .foregroundStyle(.red)
      }

      Divider()

      HStack {
        Text("Recent Recordings")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        Spacer()
        SettingsLink {
          Text("Settings")
        }
      }

      if appState.recentRecordings.isEmpty {
        Text("No recordings yet")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        ForEach(appState.recentRecordings) { recording in
          HStack {
            Text(recording.url.lastPathComponent)
              .font(.caption)
              .lineLimit(1)
            Spacer()
          }
          .contextMenu {
            Button("Open") {
              NSWorkspace.shared.open(recording.url)
            }
            Button("Reveal in Finder") {
              NSWorkspace.shared.activateFileViewerSelecting([recording.url])
            }
          }
        }
      }

      Divider()

      Button("Quit") {
        NSApp.terminate(nil)
      }
      .keyboardShortcut("q")
    }
    .padding(12)
    .frame(width: 320)
  }

  private var recordButtonTitle: String {
    switch appState.recordingState {
    case .recording(true):
      "Paused"
    case .recording(false):
      "Stop"
    case .countdown:
      "Counting down…"
    case .pickingSource:
      "Picking source…"
    case .stopping:
      "Stopping…"
    default:
      "Record"
    }
  }

  private var isRecordButtonDisabled: Bool {
    switch appState.recordingState {
    case .countdown, .pickingSource, .stopping:
      true
    default:
      false
    }
  }
}

#Preview {
  MenuBarView()
    .environmentObject(AppState.shared)
}
