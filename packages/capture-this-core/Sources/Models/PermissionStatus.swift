import Foundation

public enum PermissionStatus: Equatable, Sendable {
  case granted
  case notDetermined
  case denied
  case unknown

  public var isGranted: Bool {
    self == .granted
  }
}
