import Foundation

struct RecordingSettings: Codable {
  var countdownSeconds: Int = 3
  var isCameraEnabled: Bool = true
  var isMicrophoneEnabled: Bool = true
  var isSystemAudioEnabled: Bool = false
}
