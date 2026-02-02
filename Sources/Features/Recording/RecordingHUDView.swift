import CaptureThisCore
import SwiftUI

struct RecordingHUDView: View {
  @EnvironmentObject private var appState: AppState

  var body: some View {
    VStack(spacing: 12) {
      if case let .countdown(remaining) = appState.recordingState {
        Text("\(remaining)")
          .font(.system(size: 44, weight: .bold, design: .rounded))
          .frame(maxWidth: .infinity)
        Text("Recording starts soon")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else if case .pickingSource = appState.recordingState {
        Text("Select a source…")
          .font(.headline)
      } else if case .recording = appState.recordingState {
        TimelineView(.periodic(from: Date(), by: 1)) { _ in
          HStack(spacing: 8) {
            Circle()
              .fill(Color.red)
              .frame(width: 10, height: 10)
            Text(timerText)
              .font(.system(.body, design: .monospaced))
          }
          .frame(maxWidth: .infinity)
        }
      }

      HStack(spacing: 8) {
        if case .recording = appState.recordingState {
          Button("Stop") {
            appState.stopRecording()
          }
          .keyboardShortcut(.cancelAction)
        } else if case .countdown = appState.recordingState {
          Button("Cancel") {
            appState.cancelRecording()
          }
          .keyboardShortcut(.cancelAction)
        }
      }
    }
    .padding(16)
    .frame(width: 220)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .onExitCommand {
      appState.cancelRecording()
    }
  }

  private var timerText: String {
    guard let start = appState.recordingStartDate else { return "00:00" }
    return appState.recordingDurationText(for: start)
  }
}

#Preview {
  RecordingHUDView()
    .environmentObject(AppState.shared)
}
