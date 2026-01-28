import Foundation

enum RecordingState: Equatable {
  case idle
  case countdown(Int)
  case pickingSource
  case recording(isPaused: Bool)
  case stopping
  case error(String)

  var isRecording: Bool {
    if case .recording = self { return true }
    return false
  }
}
