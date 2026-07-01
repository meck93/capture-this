import CaptureThisCore
import Foundation

enum PermissionSetupKind: CaseIterable, Identifiable {
  case screenRecording
  case saveFolder
  case camera
  case microphone
  case notifications

  var id: Self {
    self
  }

  var title: String {
    switch self {
    case .screenRecording:
      "Screen Recording"
    case .saveFolder:
      "Save Folder"
    case .camera:
      "Camera"
    case .microphone:
      "Microphone"
    case .notifications:
      "Notifications"
    }
  }

  var detail: String {
    switch self {
    case .screenRecording:
      "Required to capture your screen."
    case .saveFolder:
      "Required to save recordings in Movies."
    case .camera:
      "Required when camera overlay is enabled."
    case .microphone:
      "Required when microphone recording is enabled."
    case .notifications:
      "Optional alert when a recording finishes."
    }
  }
}

struct PermissionSetupItem: Identifiable, Equatable {
  let kind: PermissionSetupKind
  let status: PermissionStatus
  let isRequired: Bool

  var id: PermissionSetupKind {
    kind
  }

  var actionTitle: String? {
    guard !status.isGranted else { return nil }
    if status == .denied {
      return kind == .saveFolder ? "Choose Folder" : "Open Settings"
    }
    return switch kind {
    case .screenRecording:
      "Open Settings"
    case .saveFolder:
      "Choose Folder"
    case .camera:
      "Allow Camera"
    case .microphone:
      "Allow Microphone"
    case .notifications:
      "Allow"
    }
  }

  var statusTitle: String {
    switch status {
    case .granted:
      "Granted"
    case .notDetermined:
      isRequired ? "Required" : "Optional"
    case .denied:
      "Denied"
    case .unknown:
      "Check Again"
    }
  }
}

struct PermissionSetupState: Equatable {
  var items: [PermissionSetupItem] = []

  var blocksRecording: Bool {
    items.isEmpty || items.contains { $0.isRequired && !$0.status.isGranted }
  }
}
