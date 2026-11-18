import Foundation
import os

/// Runtime debug switch. When enabled it turns on verbose logging and lets the
/// app's own windows be captured (so the popover / HUD can be screenshotted).
/// Thread-safe so services can log from any queue.
public final class DebugMode: @unchecked Sendable {
  public static let shared = DebugMode()

  private let lock = NSLock()
  private var _isEnabled = false
  private let logger = Logger(subsystem: "com.capturethis.CaptureThis", category: "Debug")

  private init() {}

  public var isEnabled: Bool {
    lock.lock()
    defer { lock.unlock() }
    return _isEnabled
  }

  public func setEnabled(_ enabled: Bool) {
    lock.lock()
    _isEnabled = enabled
    lock.unlock()
    logger.log("Debug mode \(enabled ? "enabled" : "disabled", privacy: .public)")
  }

  /// Logs only when debug mode is on. Message is autoclosed so it costs nothing when off.
  public func log(_ message: @autoclosure () -> String) {
    guard isEnabled else { return }
    let text = message()
    logger.debug("\(text, privacy: .public)")
  }
}
