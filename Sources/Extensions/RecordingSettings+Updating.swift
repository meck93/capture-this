import Foundation

extension RecordingSettings {
  func updating(
    countdownSeconds: Int? = nil,
    cameraEnabled: Bool? = nil,
    microphoneEnabled: Bool? = nil,
    systemAudioEnabled: Bool? = nil
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
    return copy
  }
}
