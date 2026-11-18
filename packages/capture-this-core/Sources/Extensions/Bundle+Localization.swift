import Foundation

private final class CoreBundleToken {}

extension Bundle {
  static var captureThisCore: Bundle {
    Bundle(for: CoreBundleToken.self)
  }
}
