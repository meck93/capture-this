import Foundation

extension AppState {
  func runStartupPermissions() {
    Task { @MainActor in
      _ = permissionService.ensureScreenRecordingAccess()
      if settings.isCameraEnabled {
        _ = await permissionService.requestCameraAccess()
      }
      if settings.isMicrophoneEnabled {
        _ = await permissionService.requestMicrophoneAccess()
      }
      await notificationService.requestAuthorization()
    }
  }
}
