import AVFoundation
import Foundation
import ScreenCaptureKit

extension CaptureService {
  func preferredFileType(from available: [AVFileType], preferred: AVFileType?) -> AVFileType {
    if let preferred, available.contains(preferred) {
      return preferred
    }
    if available.contains(.mp4) {
      return .mp4
    }
    if available.contains(.mov) {
      return .mov
    }
    return available.first ?? .mp4
  }

  func preferredVideoCodec(from available: [AVVideoCodecType], preferred: AVVideoCodecType?) -> AVVideoCodecType {
    if let preferred, available.contains(preferred) {
      return preferred
    }
    if available.contains(.h264) {
      return .h264
    }
    if available.contains(.hevc) {
      return .hevc
    }
    return available.first ?? .h264
  }

  func fileExtension(for fileType: AVFileType) -> String {
    switch fileType {
    case .mp4:
      "mp4"
    case .mov:
      "mov"
    case .m4v:
      "m4v"
    default:
      "mp4"
    }
  }
}

final class SampleStreamOutput: NSObject, SCStreamOutput {
  func stream(
    _: SCStream,
    didOutputSampleBuffer _: CMSampleBuffer,
    of _: SCStreamOutputType
  ) {}
}
