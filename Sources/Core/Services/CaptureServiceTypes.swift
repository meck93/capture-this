import AVFoundation

public struct CaptureRecordingOptions: Sendable {
  public let preferredFileType: AVFileType?
  public let preferredVideoCodec: AVVideoCodecType?

  public init(preferredFileType: AVFileType?, preferredVideoCodec: AVVideoCodecType?) {
    self.preferredFileType = preferredFileType
    self.preferredVideoCodec = preferredVideoCodec
  }
}

public struct CaptureRecordingHandlers {
  public let presenterOverlay: (Bool) -> Void
  public let error: (Error) -> Void

  public init(presenterOverlay: @escaping (Bool) -> Void, error: @escaping (Error) -> Void) {
    self.presenterOverlay = presenterOverlay
    self.error = error
  }
}
