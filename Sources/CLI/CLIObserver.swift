import CaptureThisCore
import Foundation

final class CLIObserver: RecordingObserver {
  var onFinish: ((Recording) -> Void)?
  var onError: ((Error) -> Void)?

  @MainActor
  func engineDidChangeState(_ state: RecordingState) {
    switch state {
    case .idle:
      break
    case let .countdown(remaining):
      FileHandle.standardError.write("countdown: \(remaining)\n")
    case .pickingSource:
      FileHandle.standardError.write("selecting content...\n")
    case let .recording(isPaused):
      FileHandle.standardError.write(isPaused ? "paused\n" : "recording...\n")
    case .stopping:
      FileHandle.standardError.write("stopping...\n")
    case let .error(msg):
      FileHandle.standardError.write("error: \(msg)\n")
    }
  }

  @MainActor
  func engineDidFinishRecording(_ recording: Recording) {
    onFinish?(recording)
  }

  @MainActor
  func engineDidEncounterError(_ error: Error) {
    onError?(error)
  }
}

extension FileHandle {
  func write(_ string: String) {
    write(Data(string.utf8))
  }
}
