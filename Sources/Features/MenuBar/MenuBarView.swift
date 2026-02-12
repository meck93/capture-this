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

      Button(Self.recordButtonTitle(for: appState.recordingState)) {
        appState.startOrStopRecording()
      }
      .keyboardShortcut(.defaultAction)
      .disabled(Self.isRecordButtonDisabled(for: appState.recordingState))

      if let pauseResumeTitle = Self.pauseResumeButtonTitle(for: appState.recordingState) {
        Button(pauseResumeTitle) {
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
}

extension MenuBarView {
  static func recordButtonTitle(for state: RecordingState) -> String {
    switch state {
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

  static func isRecordButtonDisabled(for state: RecordingState) -> Bool {
    switch state {
    case .countdown, .pickingSource, .stopping:
      true
    default:
      false
    }
  }

  static func pauseResumeButtonTitle(for state: RecordingState) -> String? {
    if case let .recording(isPaused) = state {
      return isPaused ? "Resume" : "Pause"
    }
    return nil
  }
}

#Preview {
  MenuBarView()
    .environmentObject(AppState.shared)
}
