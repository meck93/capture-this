import Foundation

enum CaptureSource: String, CaseIterable, Identifiable {
  case display
  case window
  case application

  var id: String {
    rawValue
  }

  var displayName: String {
    switch self {
    case .display:
      "Display"
    case .window:
      "Window"
    case .application:
      "Application"
    }
  }
}
