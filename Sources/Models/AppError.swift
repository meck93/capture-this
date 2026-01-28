import Foundation

enum AppError: LocalizedError {
  case permissionDenied
  case captureFailed
  case fileWriteFailed
  case invalidSaveLocation
  case screenRecordingDenied

  var errorDescription: String? {
    switch self {
    case .permissionDenied:
      "Required permission was denied."
    case .captureFailed:
      "Screen capture failed to start."
    case .fileWriteFailed:
      "Unable to write the recording file."
    case .invalidSaveLocation:
      "Please select the Movies folder or ~/Movies/CaptureThis to save recordings."
    case .screenRecordingDenied:
      "Screen recording permission is required. Enable it in System Settings → Privacy & Security → Screen Recording."
    }
  }
}
