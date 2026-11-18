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

    DebugMode.shared.setEnabled(AppState.shared.settings.isDebugModeEnabled)
    AppState.shared.$settings
      .map(\.isDebugModeEnabled)
      .removeDuplicates()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] enabled in
        DebugMode.shared.setEnabled(enabled)
        self?.applyCurrentSharingTypeToAllWindows()
      }
      .store(in: &cancellables)

    windowObserver = NotificationCenter.default.addObserver(
      forName: NSWindow.didBecomeKeyNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      Task { @MainActor in
        self?.applyCaptureExclusions(for: notification)
      }
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
    // Accessory apps aren't activated by a status-item click, so the popover
    // opens without a key window and the first click inside it is swallowed
    // just to focus the app. Activate + make key so the first click acts.
    NSApp.activate(ignoringOtherApps: true)
    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    DispatchQueue.main.async { [weak self] in
      guard let window = self?.popover.contentViewController?.view.window else { return }
      window.sharingType = self?.windowSharingType ?? .none
      window.makeKeyAndOrderFront(nil)
    }
    DebugMode.shared.log("Popover shown")
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

  @MainActor
  private func applyCaptureExclusions(for notification: Notification) {
    guard let window = notification.object as? NSWindow else { return }
    if window.identifier == CameraOverlayWindowController.overlayIdentifier {
      return
    }
    window.sharingType = windowSharingType
  }

  /// `.none` hides the app's own windows from screen capture. In debug mode we
  /// use `.readOnly` so the popover / settings can be screenshotted.
  private var windowSharingType: NSWindow.SharingType {
    DebugMode.shared.isEnabled ? .readOnly : .none
  }

  @MainActor
  private func applyCurrentSharingTypeToAllWindows() {
    let type = windowSharingType
    for window in NSApp.windows where window.identifier != CameraOverlayWindowController.overlayIdentifier {
      window.sharingType = type
    }
  }
}
