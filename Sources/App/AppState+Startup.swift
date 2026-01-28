import Foundation

extension AppState {
  func runStartupPermissions() {
    Task { @MainActor in
      _ = permissionService.ensureScreenRecordingAccess()
      if settings.isCameraEnabled {
        let granted = await permissionService.requestCameraAccess()
        if granted {
          try? cameraService.startPreview()
        }
      }
      if settings.isMicrophoneEnabled {
        _ = await permissionService.requestMicrophoneAccess()
      }
      _ = try? await fileAccessService.ensureRecordingsDirectoryAccess()
      await notificationService.requestAuthorization()
    }
  }
}
