import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusItem: NSStatusItem?
  private let popover = NSPopover()

  func applicationDidFinishLaunching(_ _: Notification) {
    NSApp.setActivationPolicy(.accessory)

    popover.behavior = .transient
    popover.contentViewController = NSHostingController(rootView: MenuBarView())

    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    if let button = statusItem?.button {
      button.image = NSImage(
        systemSymbolName: "record.circle", accessibilityDescription: "CaptureThis"
      )
      button.action = #selector(togglePopover)
      button.target = self
    }
  }

  @objc private func togglePopover(_ sender: AnyObject?) {
    guard let button = statusItem?.button else { return }

    if popover.isShown {
      popover.performClose(sender)
    } else {
      popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
  }
}
