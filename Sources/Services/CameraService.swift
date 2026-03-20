import AppKit
@preconcurrency import AVFoundation
import CaptureThisCore

@MainActor
final class CameraService {
  private var session: AVCaptureSession?
  private var overlayController: CameraOverlayWindowController?
  private let sessionQueue = DispatchQueue(label: "CaptureThis.CameraService")

  func startPreview() throws {
    guard session == nil else { return }
    guard let camera = AVCaptureDevice.default(for: .video) else {
      throw AppError.permissionDenied
    }

    let session = AVCaptureSession()
    let input = try AVCaptureDeviceInput(device: camera)
    if session.canAddInput(input) {
      session.addInput(input)
    }
    self.session = session

    let overlay = overlayController ?? CameraOverlayWindowController()
    overlay.attach(session: session)
    overlay.show()
    overlayController = overlay

    // AVCaptureSession start/stop can block and should not run on the main actor.
    sessionQueue.async {
      session.startRunning()
    }
  }

  func stopPreview() {
    let session = session
    self.session = nil
    overlayController?.detach()
    overlayController?.hide()

    guard let session else { return }

    // Keep session teardown serialized with startup to avoid camera shutdown races.
    sessionQueue.async {
      if session.isRunning {
        session.stopRunning()
      }
    }
  }
}
