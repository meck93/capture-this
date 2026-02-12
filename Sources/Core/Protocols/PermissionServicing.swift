public protocol PermissionServicing: AnyObject {
  func ensureScreenRecordingAccess() -> Bool
  func requestCameraAccess() async -> Bool
  func requestMicrophoneAccess() async -> Bool
}
