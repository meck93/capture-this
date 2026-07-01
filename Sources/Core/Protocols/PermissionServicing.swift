public protocol PermissionServicing: AnyObject {
  func screenRecordingStatus() -> PermissionStatus
  func cameraStatus() -> PermissionStatus
  func microphoneStatus() -> PermissionStatus
  func ensureScreenRecordingAccess() -> Bool
  func requestCameraAccess() async -> Bool
  func requestMicrophoneAccess() async -> Bool
}
