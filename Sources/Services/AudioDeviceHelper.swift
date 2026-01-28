import AVFoundation

enum AudioDeviceHelper {
  static var defaultMicrophoneID: String? {
    AVCaptureDevice.default(for: .audio)?.uniqueID
  }
}
