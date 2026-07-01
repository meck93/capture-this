import AVFoundation
import CoreGraphics
import Foundation

public final class PermissionService: PermissionServicing {
  /// `CGPreflightScreenCaptureAccess()` returns `false` for both "never asked"
  /// and "denied", so we remember whether we've ever requested to tell them
  /// apart — otherwise a fresh install looks denied before the first prompt.
  private static let hasRequestedScreenRecordingKey = "hasRequestedScreenRecording"

  private let defaults: UserDefaults

  public convenience init() {
    self.init(defaults: .standard)
  }

  public init(defaults: UserDefaults) {
    self.defaults = defaults
  }

  public func screenRecordingStatus() -> PermissionStatus {
    if CGPreflightScreenCaptureAccess() {
      return .granted
    }
    return defaults.bool(forKey: Self.hasRequestedScreenRecordingKey) ? .denied : .notDetermined
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
    defaults.set(true, forKey: Self.hasRequestedScreenRecordingKey)
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
