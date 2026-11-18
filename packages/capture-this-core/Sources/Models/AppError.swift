import Foundation

public enum AppError: LocalizedError {
  case permissionDenied
  case captureFailed
  case fileWriteFailed
  case invalidSaveLocation
  case screenRecordingDenied

  public var errorDescription: String? {
    switch self {
    case .permissionDenied:
      String(localized: "Required permission was denied.", bundle: .captureThisCore)
    case .captureFailed:
      String(localized: "Screen capture failed to start.", bundle: .captureThisCore)
    case .fileWriteFailed:
      String(localized: "Unable to write the recording file.", bundle: .captureThisCore)
    case .invalidSaveLocation:
      String(
        localized: "Please select the Movies folder or ~/Movies/CaptureThis to save recordings.",
        bundle: .captureThisCore
      )
    case .screenRecordingDenied:
      String(localized: "error.screenRecordingDenied", bundle: .captureThisCore)
    }
  }
}
