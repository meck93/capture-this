import AppKit
import AVFoundation

@MainActor
final class CameraService {
  private var session: AVCaptureSession?
  private var overlayController: CameraOverlayWindowController?

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
    session.startRunning()
    self.session = session

    let overlay = overlayController ?? CameraOverlayWindowController()
    overlay.attach(session: session)
    overlay.show()
    overlayController = overlay
  }

  func stopPreview() {
    session?.stopRunning()
    session = nil
    overlayController?.hide()
  }
}
