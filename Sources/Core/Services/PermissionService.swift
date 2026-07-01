import AVFoundation
import CoreGraphics
import Foundation

public final class PermissionService: PermissionServicing {
  public init() {}

  public func screenRecordingStatus() -> PermissionStatus {
    CGPreflightScreenCaptureAccess() ? .granted : .denied
  }

  public func cameraStatus() -> PermissionStatus {
    status(for: AVCaptureDevice.authorizationStatus(for: .video))
  }

  public func microphoneStatus() -> PermissionStatus {
    status(for: AVCaptureDevice.authorizationStatus(for: .audio))
  }

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

  private func status(for authorizationStatus: AVAuthorizationStatus) -> PermissionStatus {
    switch authorizationStatus {
    case .authorized:
      .granted
    case .notDetermined:
      .notDetermined
    case .denied, .restricted:
      .denied
    @unknown default:
      .unknown
    }
  }
}
