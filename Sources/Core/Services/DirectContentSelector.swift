import Foundation
import ScreenCaptureKit

public final class DirectContentSelector: ContentSelector {
  public init() {}

  public func selectContent(source: CaptureSource) async throws -> SCContentFilter? {
    let content = try await SCShareableContent.current
    switch source {
    case .display:
      guard let display = content.displays.first else { return nil }
      return SCContentFilter(display: display, excludingWindows: [])
    case .window:
      guard let window = content.windows.first(where: { $0.isOnScreen }) else { return nil }
      return SCContentFilter(desktopIndependentWindow: window)
    case .application:
      guard let app = content.applications.first(where: { !$0.bundleIdentifier.isEmpty }) else { return nil }
      let display = content.displays.first!
      return SCContentFilter(display: display, including: [app], exceptingWindows: [])
    }
  }

  public func cancel() async {}
}
