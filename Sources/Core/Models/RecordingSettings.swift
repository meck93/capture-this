import Foundation

public enum RecordingFileFormat: String, Codable, CaseIterable, Identifiable, Sendable {
  case mp4
  case mov

  public var id: String {
    rawValue
  }

  public var displayName: String {
    switch self {
    case .mp4:
      String(localized: "MP4", bundle: .captureThisCore)
    case .mov:
      String(localized: "MOV", bundle: .captureThisCore)
    }
  }
}

public enum RecordingQuality: String, Codable, CaseIterable, Identifiable, Sendable {
  case standard
  case high

  public var id: String {
    rawValue
  }

  public var displayName: String {
    switch self {
    case .standard:
      String(localized: "Standard (H.264)", bundle: .captureThisCore)
    case .high:
      String(localized: "High (HEVC)", bundle: .captureThisCore)
    }
  }
}

public enum GIFExportQuality: String, Codable, CaseIterable, Identifiable, Sendable {
  case compact
  case balanced
  case high

  public var id: String {
    rawValue
  }

  public var displayName: String {
    switch self {
    case .compact:
      String(localized: "Compact", bundle: .captureThisCore)
    case .balanced:
      String(localized: "Balanced", bundle: .captureThisCore)
    case .high:
      String(localized: "High", bundle: .captureThisCore)
    }
  }

  public var targetWidth: Double {
    switch self {
    case .compact: 1080
    case .balanced: 1440
    case .high: 2160
    }
  }

  public var framesPerSecond: Double {
    switch self {
    case .compact: 15
    case .balanced: 24
    case .high: 24
    }
  }
}

public struct RecordingSettings: Codable, Sendable {
  public var countdownSeconds: Int
  public var isCameraEnabled: Bool
  public var isMicrophoneEnabled: Bool
  public var isSystemAudioEnabled: Bool
  public var outputFormat: RecordingFileFormat
  public var recordingQuality: RecordingQuality
  public var gifExportQuality: GIFExportQuality
  public var isDebugModeEnabled: Bool

  public init(
    countdownSeconds: Int = 3,
    isCameraEnabled: Bool = true,
    isMicrophoneEnabled: Bool = true,
    isSystemAudioEnabled: Bool = false,
    outputFormat: RecordingFileFormat = .mp4,
    recordingQuality: RecordingQuality = .standard,
    gifExportQuality: GIFExportQuality = .balanced,
    isDebugModeEnabled: Bool = false
  ) {
    self.countdownSeconds = countdownSeconds
    self.isCameraEnabled = isCameraEnabled
    self.isMicrophoneEnabled = isMicrophoneEnabled
    self.isSystemAudioEnabled = isSystemAudioEnabled
    self.outputFormat = outputFormat
    self.recordingQuality = recordingQuality
    self.gifExportQuality = gifExportQuality
    self.isDebugModeEnabled = isDebugModeEnabled
  }

  /// Tolerant decoding so settings persisted before a field existed still load.
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let defaults = RecordingSettings()
    func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) throws -> T {
      try container.decodeIfPresent(T.self, forKey: key) ?? fallback
    }
    countdownSeconds = try value(.countdownSeconds, defaults.countdownSeconds)
    isCameraEnabled = try value(.isCameraEnabled, defaults.isCameraEnabled)
    isMicrophoneEnabled = try value(.isMicrophoneEnabled, defaults.isMicrophoneEnabled)
    isSystemAudioEnabled = try value(.isSystemAudioEnabled, defaults.isSystemAudioEnabled)
    outputFormat = try value(.outputFormat, defaults.outputFormat)
    recordingQuality = try value(.recordingQuality, defaults.recordingQuality)
    gifExportQuality = try value(.gifExportQuality, defaults.gifExportQuality)
    isDebugModeEnabled = try value(.isDebugModeEnabled, defaults.isDebugModeEnabled)
  }
}
