import AppKit
@preconcurrency import AVFoundation
import CaptureThisCore
import os

@MainActor
final class CameraService {
  private var session: AVCaptureSession?
  private var overlayController: CameraOverlayWindowController?
  private let sessionQueue = DispatchQueue(label: "CaptureThis.CameraService")
  private let logger = Logger(subsystem: "com.capturethis.CaptureThis", category: "Camera")

  func startPreview() throws {
    guard session == nil else {
      logger.debug("Camera preview already running")
      return
    }
    guard let camera = AVCaptureDevice.default(for: .video) else {
      logger.error("Unable to find default camera")
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
    let logger = logger
    sessionQueue.async {
      logger.notice("Starting camera preview session")
      session.startRunning()
      logger.notice("Camera preview session started")
    }
  }

  func stopPreview() {
    let session = session
    self.session = nil
    overlayController?.detach()
    overlayController?.hide()
    overlayController = nil

    guard let session else {
      logger.debug("Camera preview stop requested with no active session")
      return
    }

    // Keep session teardown serialized with startup to avoid camera shutdown races.
    let logger = logger
    sessionQueue.async {
      logger.notice("Stopping camera preview session")
      if session.isRunning {
        session.stopRunning()
      }
      session.beginConfiguration()
      for input in session.inputs {
        session.removeInput(input)
      }
      for output in session.outputs {
        session.removeOutput(output)
      }
      session.commitConfiguration()
      logger.notice("Camera preview session stopped and detached")
    }
  }
}
