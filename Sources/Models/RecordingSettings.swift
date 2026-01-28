import Foundation

enum RecordingFileFormat: String, Codable, CaseIterable, Identifiable {
  case mp4
  case mov

  var id: String {
    rawValue
  }

  var displayName: String {
    switch self {
    case .mp4:
      "MP4"
    case .mov:
      "MOV"
    }
  }
}

enum RecordingQuality: String, Codable, CaseIterable, Identifiable {
  case standard
  case high

  var id: String {
    rawValue
  }

  var displayName: String {
    switch self {
    case .standard:
      "Standard (H.264)"
    case .high:
      "High (HEVC)"
    }
  }
}

struct RecordingSettings: Codable {
  var countdownSeconds: Int = 3
  var isCameraEnabled: Bool = true
  var isMicrophoneEnabled: Bool = true
  var isSystemAudioEnabled: Bool = false
  var outputFormat: RecordingFileFormat = .mp4
  var recordingQuality: RecordingQuality = .standard
}
