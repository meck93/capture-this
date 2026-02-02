import AVFoundation
import Foundation
import ScreenCaptureKit

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

public final class CaptureService: NSObject {
  private var stream: SCStream?
  private var recordingOutput: SCRecordingOutput?
  private var outputURL: URL?
  private var finishContinuation: CheckedContinuation<URL, Error>?
  private var presenterOverlayHandler: ((Bool) -> Void)?
  private var errorHandler: ((Error) -> Void)?
  private let sampleOutput = SampleStreamOutput()
  private let sampleQueue = DispatchQueue(label: "CaptureThis.SampleOutput")

  override public init() {
    super.init()
  }

  public func startRecording(
    filter: SCContentFilter,
    configuration: SCStreamConfiguration,
    outputURL: URL,
    options: CaptureRecordingOptions,
    handlers: CaptureRecordingHandlers
  ) async throws {
    if stream != nil {
      try await stopAndReset()
    }

    self.outputURL = outputURL
    presenterOverlayHandler = handlers.presenterOverlay
    errorHandler = handlers.error

    let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
    let recordingConfig = SCRecordingOutputConfiguration()
    let outputFileType = preferredFileType(
      from: recordingConfig.availableOutputFileTypes,
      preferred: options.preferredFileType
    )
    let videoCodec = preferredVideoCodec(
      from: recordingConfig.availableVideoCodecTypes,
      preferred: options.preferredVideoCodec
    )
    let resolvedOutputURL = outputURL
      .deletingPathExtension()
      .appendingPathExtension(fileExtension(for: outputFileType))

    recordingConfig.outputURL = resolvedOutputURL
    recordingConfig.outputFileType = outputFileType
    recordingConfig.videoCodecType = videoCodec

    self.outputURL = resolvedOutputURL
    let recordingOutput = SCRecordingOutput(configuration: recordingConfig, delegate: self)

    try stream.addStreamOutput(sampleOutput, type: .screen, sampleHandlerQueue: sampleQueue)
    if configuration.capturesAudio {
      try stream.addStreamOutput(sampleOutput, type: .audio, sampleHandlerQueue: sampleQueue)
    }
    if configuration.captureMicrophone {
      try stream.addStreamOutput(sampleOutput, type: .microphone, sampleHandlerQueue: sampleQueue)
    }

    try stream.addRecordingOutput(recordingOutput)
    try await stream.startCapture()

    self.stream = stream
    self.recordingOutput = recordingOutput
  }

  public func stopRecording() async throws -> URL {
    guard let stream, let recordingOutput else {
      throw AppError.captureFailed
    }

    return try await withCheckedThrowingContinuation { continuation in
      finishContinuation = continuation
      do {
        try stream.removeRecordingOutput(recordingOutput)
      } catch {
        finishContinuation?.resume(throwing: error)
        finishContinuation = nil
        return
      }
    }
  }

  private func stopAndReset() async throws {
    if let recordingOutput, let stream {
      try? stream.removeStreamOutput(sampleOutput, type: .screen)
      try? stream.removeStreamOutput(sampleOutput, type: .audio)
      try? stream.removeStreamOutput(sampleOutput, type: .microphone)
      try? stream.removeRecordingOutput(recordingOutput)
      try? await stream.stopCapture()
    }
    stream = nil
    recordingOutput = nil
    outputURL = nil
  }
}

extension CaptureService: SCStreamDelegate {
  public func stream(_: SCStream, didStopWithError error: Error) {
    let hadContinuation = finishContinuation != nil
    finishContinuation?.resume(throwing: error)
    finishContinuation = nil
    if !hadContinuation {
      errorHandler?(error)
    }
    stream = nil
    recordingOutput = nil
    outputURL = nil
  }

  public func stream(_: SCStream, outputEffectDidStart didStart: Bool) {
    presenterOverlayHandler?(didStart)
  }
}

extension CaptureService: SCRecordingOutputDelegate {
  public func recordingOutputDidFinishRecording(_: SCRecordingOutput) {
    if let outputURL {
      finishContinuation?.resume(returning: outputURL)
      finishContinuation = nil
    }
    Task { [weak self] in
      try? await self?.stopAndReset()
    }
  }

  public func recordingOutput(_: SCRecordingOutput, didFailWithError error: Error) {
    let hadContinuation = finishContinuation != nil
    finishContinuation?.resume(throwing: error)
    finishContinuation = nil
    if !hadContinuation {
      errorHandler?(error)
    }
    Task { [weak self] in
      try? await self?.stopAndReset()
    }
  }
}

extension CaptureService {
  private func preferredFileType(from available: [AVFileType], preferred: AVFileType?) -> AVFileType {
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

  private func preferredVideoCodec(
    from available: [AVVideoCodecType],
    preferred: AVVideoCodecType?
  ) -> AVVideoCodecType {
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

  private func fileExtension(for fileType: AVFileType) -> String {
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

private final class SampleStreamOutput: NSObject, SCStreamOutput {
  func stream(
    _: SCStream,
    didOutputSampleBuffer _: CMSampleBuffer,
    of _: SCStreamOutputType
  ) {}
}
