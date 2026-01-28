import AppKit
import AVFoundation

@MainActor
final class CameraOverlayWindowController {
  static let overlayIdentifier = NSUserInterfaceItemIdentifier("CameraOverlayWindow")
  private let window: NSPanel
  private let previewView: CameraPreviewView

  init() {
    previewView = CameraPreviewView(frame: NSRect(x: 0, y: 0, width: 220, height: 140))

    let panel = NSPanel(
      contentRect: previewView.frame,
      styleMask: [.nonactivatingPanel, .borderless],
      backing: .buffered,
      defer: false
    )

    panel.level = .floating
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.isFloatingPanel = true
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.ignoresMouseEvents = false
    panel.hidesOnDeactivate = false
    panel.titleVisibility = .hidden
    panel.titlebarAppearsTransparent = true
    panel.isMovableByWindowBackground = true
    panel.contentView = previewView
    panel.sharingType = .readOnly
    panel.identifier = Self.overlayIdentifier

    window = panel
    positionPanel()
  }

  func attach(session: AVCaptureSession) {
    previewView.attach(session: session)
  }

  func show() {
    positionPanel()
    window.orderFrontRegardless()
  }

  func hide() {
    window.orderOut(nil)
  }

  private func positionPanel() {
    guard let screen = NSScreen.main else { return }
    let frame = screen.visibleFrame
    let panelSize = window.frame.size
    let xPosition = frame.maxX - panelSize.width - 20
    let yPosition = frame.minY + 20
    window.setFrameOrigin(NSPoint(x: xPosition, y: yPosition))
  }
}

@MainActor
final class CameraPreviewView: NSView {
  private let previewLayer = AVCaptureVideoPreviewLayer()
  private let backgroundLayer = CALayer()

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
    layer = CALayer()
    layer?.masksToBounds = true
    layer?.cornerRadius = 10

    backgroundLayer.backgroundColor = NSColor.black.withAlphaComponent(0.75).cgColor
    layer?.addSublayer(backgroundLayer)

    previewLayer.videoGravity = .resizeAspectFill
    layer?.addSublayer(previewLayer)
  }

  required init?(coder _: NSCoder) {
    nil
  }

  func attach(session: AVCaptureSession) {
    previewLayer.session = session
  }

  override func layout() {
    super.layout()
    backgroundLayer.frame = bounds
    previewLayer.frame = bounds
  }
}
