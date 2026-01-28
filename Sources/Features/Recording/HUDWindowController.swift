import AppKit
import SwiftUI

@MainActor
final class HUDWindowController {
  private var window: NSPanel

  var isVisible: Bool {
    window.isVisible
  }

  init(appState: AppState) {
    let contentView = RecordingHUDView().environmentObject(appState)
    let hosting = NSHostingView(rootView: contentView)

    let panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 240, height: 120),
      styleMask: [.nonactivatingPanel, .borderless],
      backing: .buffered,
      defer: false
    )

    panel.level = .statusBar
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.isFloatingPanel = true
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.ignoresMouseEvents = false
    panel.hidesOnDeactivate = false
    panel.titleVisibility = .hidden
    panel.titlebarAppearsTransparent = true
    panel.isMovableByWindowBackground = false
    panel.contentView = hosting
    panel.sharingType = .none

    window = panel
    positionPanel()
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
    let yPosition = frame.maxY - panelSize.height - 20
    window.setFrameOrigin(NSPoint(x: xPosition, y: yPosition))
  }
}
