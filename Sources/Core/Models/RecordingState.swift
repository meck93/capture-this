import Foundation

public enum RecordingState: Equatable, Sendable {
  case idle
  case countdown(Int)
  case pickingSource
  case recording(isPaused: Bool)
  case stopping
  case error(String)

  public var isRecording: Bool {
    if case .recording = self { return true }
    return false
  }

  public var shouldEnableCancelHotKey: Bool {
    switch self {
    case .countdown, .pickingSource, .recording, .stopping:
      true
    case .idle, .error:
      false
    }
  }
}
