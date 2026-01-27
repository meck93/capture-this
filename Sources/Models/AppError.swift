import Foundation

enum AppError: LocalizedError {
  case permissionDenied
  case captureFailed
  case fileWriteFailed

  var errorDescription: String? {
    switch self {
    case .permissionDenied:
      "Required permission was denied."
    case .captureFailed:
      "Screen capture failed to start."
    case .fileWriteFailed:
      "Unable to write the recording file."
    }
  }
}
