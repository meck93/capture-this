import CaptureThisCore
import Foundation

extension AppState {
  func runStartupPermissions() {
    Task { @MainActor in
      _ = engine.permissionService.ensureScreenRecordingAccess()
      if settings.isCameraEnabled {
        let granted = await engine.permissionService.requestCameraAccess()
        if granted {
          try? cameraService.startPreview()
        }
      }
      if settings.isMicrophoneEnabled {
        _ = await engine.permissionService.requestMicrophoneAccess()
      }
      let fileAccess = FileAccessService()
      _ = try? await fileAccess.ensureRecordingsDirectoryAccess()
      await notificationService.requestAuthorization()
    }
  }
}
