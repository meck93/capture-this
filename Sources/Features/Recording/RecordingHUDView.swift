import CaptureThisCore
import SwiftUI

struct RecordingHUDView: View {
  @EnvironmentObject private var appState: AppState

  var body: some View {
    let recordingState = appState.recordingState

    VStack(spacing: 12) {
      if case let .countdown(remaining) = recordingState {
        Text("\(remaining)")
          .font(.system(size: 44, weight: .bold, design: .rounded))
          .frame(maxWidth: .infinity)
        Text("Recording starts soon")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else if case .pickingSource = recordingState {
        Text("Select a source…")
          .font(.headline)
      } else if Self.usesTimeline(for: recordingState) {
        if let indicatorColorName = Self.indicatorColorName(for: recordingState) {
          TimelineView(.periodic(from: Date(), by: 1)) { _ in
            HStack(spacing: 8) {
              Circle()
                .fill(color(named: indicatorColorName))
                .frame(width: 10, height: 10)
              Text(timerText)
                .font(.system(.body, design: .monospaced))
            }
            .frame(maxWidth: .infinity)
          }
        }
      } else if let indicatorColorName = Self.indicatorColorName(for: recordingState) {
        HStack(spacing: 8) {
          Circle()
            .fill(color(named: indicatorColorName))
            .frame(width: 10, height: 10)
          Text(timerText)
            .font(.system(.body, design: .monospaced))
        }
        .frame(maxWidth: .infinity)
      }

      HStack(spacing: 8) {
        if case let .recording(isPaused) = recordingState {
          Button {
            appState.togglePauseResume()
          } label: {
            Image(systemName: Self.pauseResumeSymbolName(for: recordingState) ?? "pause.fill")
              .frame(width: 18)
          }
          .help(isPaused ? "Resume" : "Pause")

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

  private func color(named colorName: String) -> Color {
    switch colorName {
    case "orange":
      .orange
    case "red":
      .red
    default:
      .red
    }
  }
}

extension RecordingHUDView {
  static func usesTimeline(for state: RecordingState) -> Bool {
    if case .recording(false) = state {
      return true
    }
    return false
  }

  static func indicatorColorName(for state: RecordingState) -> String? {
    switch state {
    case .recording(true):
      "orange"
    case .recording(false):
      "red"
    default:
      nil
    }
  }

  static func pauseResumeSymbolName(for state: RecordingState) -> String? {
    switch state {
    case .recording(true):
      "play.fill"
    case .recording(false):
      "pause.fill"
    default:
      nil
    }
  }
}

#Preview {
  RecordingHUDView()
    .environmentObject(AppState.shared)
}
