import Foundation

public enum ShortcutAction: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
  case startStop
  case pauseResume
  case openApp
  case cancel

  public var id: String {
    rawValue
  }

  public var displayName: String {
    switch self {
    case .startStop:
      String(localized: "Start/Stop recording", bundle: .captureThisCore)
    case .pauseResume:
      String(localized: "Pause/Resume", bundle: .captureThisCore)
    case .openApp:
      String(localized: "Toggle CaptureThis", bundle: .captureThisCore)
    case .cancel:
      String(localized: "Cancel selection", bundle: .captureThisCore)
    }
  }
}

public struct ShortcutBinding: Codable, Equatable, Hashable, Sendable {
  public let keyCode: UInt32
  public let modifiers: UInt32

  public init(keyCode: UInt32, modifiers: UInt32) {
    self.keyCode = keyCode
    self.modifiers = modifiers
  }
}

public struct KeyboardShortcutSettings: Codable, Equatable, Sendable {
  private enum CodingKeys: String, CodingKey {
    case isEnabled
    case startStop
    case pauseResume
    case openApp
    case cancel
  }

  public var isEnabled: Bool
  public var startStop: ShortcutBinding?
  public var pauseResume: ShortcutBinding?
  public var openApp: ShortcutBinding?
  public var cancel: ShortcutBinding?

  public init(
    isEnabled: Bool = false,
    startStop: ShortcutBinding? = ShortcutBinding(keyCode: 15, modifiers: 768),
    pauseResume: ShortcutBinding? = nil,
    openApp: ShortcutBinding? = ShortcutBinding(keyCode: 8, modifiers: 768),
    cancel: ShortcutBinding? = ShortcutBinding(keyCode: 53, modifiers: 0)
  ) {
    self.isEnabled = isEnabled
    self.startStop = startStop
    self.pauseResume = pauseResume
    self.openApp = openApp
    self.cancel = cancel
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(isEnabled, forKey: .isEnabled)
    try encodeOptional(startStop, forKey: .startStop, into: &container)
    try encodeOptional(pauseResume, forKey: .pauseResume, into: &container)
    try encodeOptional(openApp, forKey: .openApp, into: &container)
    try encodeOptional(cancel, forKey: .cancel, into: &container)
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let defaults = KeyboardShortcutSettings()

    func optionalValue<T: Decodable>(_ key: CodingKeys, fallback: T?) throws -> T? {
      guard container.contains(key) else { return fallback }
      return try container.decodeIfPresent(T.self, forKey: key)
    }

    isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? defaults.isEnabled
    startStop = try optionalValue(.startStop, fallback: defaults.startStop)
    pauseResume = try optionalValue(.pauseResume, fallback: defaults.pauseResume)
    openApp = try optionalValue(.openApp, fallback: defaults.openApp)
    cancel = try optionalValue(.cancel, fallback: defaults.cancel)
  }

  private func encodeOptional(
    _ value: (some Encodable)?,
    forKey key: CodingKeys,
    into container: inout KeyedEncodingContainer<CodingKeys>
  ) throws {
    if let value {
      try container.encode(value, forKey: key)
    } else {
      try container.encodeNil(forKey: key)
    }
  }

  public func binding(for action: ShortcutAction) -> ShortcutBinding? {
    switch action {
    case .startStop:
      startStop
    case .pauseResume:
      pauseResume
    case .openApp:
      openApp
    case .cancel:
      cancel
    }
  }

  public func updating(_ action: ShortcutAction, with binding: ShortcutBinding?) -> KeyboardShortcutSettings {
    var copy = self
    switch action {
    case .startStop:
      copy.startStop = binding
    case .pauseResume:
      copy.pauseResume = binding
    case .openApp:
      copy.openApp = binding
    case .cancel:
      copy.cancel = binding
    }
    return copy
  }
}
