import AVFoundation
import CoreGraphics
import Foundation

final class PermissionService {
  func ensureScreenRecordingAccess() -> Bool {
    if CGPreflightScreenCaptureAccess() {
      return true
    }
    return CGRequestScreenCaptureAccess()
  }

  func requestCameraAccess() async -> Bool {
    await withCheckedContinuation { continuation in
      AVCaptureDevice.requestAccess(for: .video) { granted in
        continuation.resume(returning: granted)
      }
    }
  }

  func requestMicrophoneAccess() async -> Bool {
    await withCheckedContinuation { continuation in
      AVCaptureDevice.requestAccess(for: .audio) { granted in
        continuation.resume(returning: granted)
      }
    }
  }
}
