import ArgumentParser
import Foundation
import ScreenCaptureKit

struct ListCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "list",
    abstract: "List available capture sources"
  )

  @Argument(help: "What to list: displays, windows")
  var kind: String = "displays"

  func run() async throws {
    let content = try await SCShareableContent.current

    switch kind {
    case "displays":
      for (idx, display) in content.displays.enumerated() {
        print("[\(idx)] display \(display.displayID): \(display.width)x\(display.height)")
      }
    case "windows":
      for window in content.windows where window.isOnScreen {
        let app = window.owningApplication?.bundleIdentifier ?? "unknown"
        let title = window.title ?? "(untitled)"
        print("[\(window.windowID)] \(app): \(title)")
      }
    default:
      print("unknown kind: \(kind). Use 'displays' or 'windows'.")
    }
  }
}
