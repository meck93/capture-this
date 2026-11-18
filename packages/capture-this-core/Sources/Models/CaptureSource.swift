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
      String(localized: "Display", bundle: .captureThisCore)
    case .window:
      String(localized: "Window", bundle: .captureThisCore)
    case .application:
      String(localized: "Application", bundle: .captureThisCore)
    }
  }
}
