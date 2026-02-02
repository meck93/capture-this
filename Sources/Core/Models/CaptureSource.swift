import Foundation

public enum CaptureSource: String, CaseIterable, Identifiable, Sendable {
  case display
  case window
  case application

  public var id: String {
    rawValue
  }

  public var displayName: String {
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
