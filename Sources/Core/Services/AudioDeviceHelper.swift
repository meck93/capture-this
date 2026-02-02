import AVFoundation

public enum AudioDeviceHelper {
  public static var defaultMicrophoneID: String? {
    AVCaptureDevice.default(for: .audio)?.uniqueID
  }
}
