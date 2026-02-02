import AVFoundation
import CoreGraphics
import Foundation

public final class PermissionService {
  public init() {}

  public func ensureScreenRecordingAccess() -> Bool {
    if CGPreflightScreenCaptureAccess() {
      return true
    }
    return CGRequestScreenCaptureAccess()
  }

  public func requestCameraAccess() async -> Bool {
    await withCheckedContinuation { continuation in
      AVCaptureDevice.requestAccess(for: .video) { granted in
        continuation.resume(returning: granted)
      }
    }
  }

  public func requestMicrophoneAccess() async -> Bool {
    await withCheckedContinuation { continuation in
      AVCaptureDevice.requestAccess(for: .audio) { granted in
        continuation.resume(returning: granted)
      }
    }
  }
}
