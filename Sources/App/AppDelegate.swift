import AppKit
import CaptureThisCore
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
  static var shared: AppDelegate?

  private var statusItem: NSStatusItem?
  private let popover = NSPopover()
  private var cancellables = Set<AnyCancellable>()
  private var windowObserver: Any?
  private var clickMonitor: Any?

  func applicationDidFinishLaunching(_: Notification) {
    AppDelegate.shared = self
    NSApp.setActivationPolicy(.accessory)

    popover.behavior = .transient
    popover.contentViewController = NSHostingController(
      rootView: MenuBarView().environmentObject(AppState.shared)
    )

    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    if let button = statusItem?.button {
      if let baseImage = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "CaptureThis") {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let image = baseImage.withSymbolConfiguration(config) ?? baseImage
        image.isTemplate = true
        button.image = image
      } else {
        button.title = "CT"
      }
      button.toolTip = "CaptureThis"
      button.action = #selector(togglePopover)
      button.target = self
    }
    statusItem?.isVisible = true

    AppState.shared.$recordingState
      .receive(on: DispatchQueue.main)
      .sink { [weak self] state in
        self?.updateStatusIcon(for: state)
      }
      .store(in: &cancellables)

    _ = NotificationService.shared
    AppState.shared.runStartupPermissions()

    windowObserver = NotificationCenter.default.addObserver(
      forName: NSWindow.didBecomeKeyNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      self?.applyCaptureExclusions(for: notification)
    }
  }

  @objc func togglePopover(_ _: AnyObject?) {
    if popover.isShown {
      closePopover()
    } else {
      showPopover()
    }
  }

  func showPopover() {
    guard let button = statusItem?.button else { return }
    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    DispatchQueue.main.async { [weak self] in
      self?.popover.contentViewController?.view.window?.sharingType = .none
    }
    clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
      self?.closePopover()
    }
  }

  private func closePopover() {
    popover.performClose(nil)
    if let monitor = clickMonitor {
      NSEvent.removeMonitor(monitor)
      clickMonitor = nil
    }
  }

  private func updateStatusIcon(for state: RecordingState) {
    guard let button = statusItem?.button else { return }
    let symbolName = switch state {
    case .recording:
      "record.circle.fill"
    case .countdown:
      "record.circle.dashed"
    default:
      "record.circle"
    }

    button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "CaptureThis")
  }

  private func applyCaptureExclusions(for notification: Notification) {
    guard let window = notification.object as? NSWindow else { return }
    if window.identifier == CameraOverlayWindowController.overlayIdentifier {
      return
    }
    window.sharingType = .none
  }
}
