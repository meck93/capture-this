import Foundation

public extension RecordingSettings {
  func updating(
    countdownSeconds: Int? = nil,
    cameraEnabled: Bool? = nil,
    microphoneEnabled: Bool? = nil,
    systemAudioEnabled: Bool? = nil,
    outputFormat: RecordingFileFormat? = nil,
    recordingQuality: RecordingQuality? = nil
  ) -> RecordingSettings {
    var copy = self
    if let countdownSeconds {
      copy.countdownSeconds = countdownSeconds
    }
    if let cameraEnabled {
      copy.isCameraEnabled = cameraEnabled
    }
    if let microphoneEnabled {
      copy.isMicrophoneEnabled = microphoneEnabled
    }
    if let systemAudioEnabled {
      copy.isSystemAudioEnabled = systemAudioEnabled
    }
    if let outputFormat {
      copy.outputFormat = outputFormat
    }
    if let recordingQuality {
      copy.recordingQuality = recordingQuality
    }
    return copy
  }
}
