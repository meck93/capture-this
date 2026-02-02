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
      "MP4"
    case .mov:
      "MOV"
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
      "Standard (H.264)"
    case .high:
      "High (HEVC)"
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

  public init(
    countdownSeconds: Int = 3,
    isCameraEnabled: Bool = true,
    isMicrophoneEnabled: Bool = true,
    isSystemAudioEnabled: Bool = false,
    outputFormat: RecordingFileFormat = .mp4,
    recordingQuality: RecordingQuality = .standard
  ) {
    self.countdownSeconds = countdownSeconds
    self.isCameraEnabled = isCameraEnabled
    self.isMicrophoneEnabled = isMicrophoneEnabled
    self.isSystemAudioEnabled = isSystemAudioEnabled
    self.outputFormat = outputFormat
    self.recordingQuality = recordingQuality
  }
}
