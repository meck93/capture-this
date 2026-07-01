import AppKit
import CaptureThisCore
import Foundation

extension AppState {
  func refreshPermissionSetupState() {
    Task { @MainActor in
      let notificationStatus = await notificationService.authorizationStatus()
      permissionSetupState = PermissionSetupState(items: permissionSetupItems(notificationStatus: notificationStatus))
    }
  }

  func performPermissionSetupAction(for kind: PermissionSetupKind) {
    Task { @MainActor in
      switch kind {
      case .screenRecording:
        openScreenRecordingSettings()
      case .saveFolder:
        _ = try? await fileAccessService.ensureRecordingsDirectoryAccess()
      case .camera:
        if engine.permissionService.cameraStatus() == .denied {
          openPrivacySettings(anchor: "Privacy_Camera")
        } else {
          _ = await engine.permissionService.requestCameraAccess()
        }
      case .microphone:
        if engine.permissionService.microphoneStatus() == .denied {
          openPrivacySettings(anchor: "Privacy_Microphone")
        } else {
          _ = await engine.permissionService.requestMicrophoneAccess()
        }
      case .notifications:
        if await notificationService.authorizationStatus() == .denied {
          openNotificationsSettings()
        } else {
          await notificationService.requestAuthorization()
        }
      }
      refreshPermissionSetupState()
    }
  }

  func openSetupForMissingPermissions() {
    refreshPermissionSetupState()
    openMenuBarPopover()
  }

  private func permissionSetupItems(notificationStatus: PermissionStatus) -> [PermissionSetupItem] {
    var items = [
      PermissionSetupItem(
        kind: .screenRecording,
        status: engine.permissionService.screenRecordingStatus(),
        isRequired: true
      ),
      PermissionSetupItem(
        kind: .saveFolder,
        status: fileAccessService.recordingsDirectoryAccessStatus(),
        isRequired: true
      )
    ]

    if settings.isCameraEnabled {
      items.append(
        PermissionSetupItem(
          kind: .camera,
          status: engine.permissionService.cameraStatus(),
          isRequired: true
        )
      )
    }

    if settings.isMicrophoneEnabled {
      items.append(
        PermissionSetupItem(
          kind: .microphone,
          status: engine.permissionService.microphoneStatus(),
          isRequired: true
        )
      )
    }

    items.append(
      PermissionSetupItem(
        kind: .notifications,
        status: notificationStatus,
        isRequired: false
      )
    )

    return items
  }

  private func openScreenRecordingSettings() {
    openPrivacySettings(anchor: "Privacy_ScreenCapture")
  }

  private func openPrivacySettings(anchor: String) {
    guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else {
      return
    }
    NSWorkspace.shared.open(url)
  }

  private func openNotificationsSettings() {
    guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else {
      return
    }
    NSWorkspace.shared.open(url)
  }
}
