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
      String(localized: "Screen Recording")
    case .saveFolder:
      String(localized: "Save Folder")
    case .camera:
      String(localized: "Camera")
    case .microphone:
      String(localized: "Microphone")
    case .notifications:
      String(localized: "Notifications")
    }
  }

  var detail: String {
    switch self {
    case .screenRecording:
      String(localized: "Required to capture your screen.")
    case .saveFolder:
      String(localized: "Required to save recordings in Movies.")
    case .camera:
      String(localized: "Required when camera overlay is enabled.")
    case .microphone:
      String(localized: "Required when microphone recording is enabled.")
    case .notifications:
      String(localized: "Optional alert when a recording finishes.")
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
      return kind == .saveFolder ? String(localized: "Choose Folder") : String(localized: "Open Settings")
    }
    return switch kind {
    case .screenRecording:
      String(localized: "Open Settings")
    case .saveFolder:
      String(localized: "Choose Folder")
    case .camera:
      String(localized: "Allow Camera")
    case .microphone:
      String(localized: "Allow Microphone")
    case .notifications:
      String(localized: "Allow")
    }
  }

  var statusTitle: String {
    switch status {
    case .granted:
      String(localized: "Granted")
    case .notDetermined:
      if isRequired {
        String(localized: "Required")
      } else {
        String(localized: "Optional")
      }
    case .denied:
      String(localized: "Denied")
    case .unknown:
      String(localized: "Check Again")
    }
  }
}

struct PermissionSetupState: Equatable {
  var items: [PermissionSetupItem] = []

  var blocksRecording: Bool {
    items.isEmpty || items.contains { $0.isRequired && !$0.status.isGranted }
  }
}
