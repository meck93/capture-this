import AVFoundation
import Foundation
import ScreenCaptureKit

final class CaptureService: NSObject {
  private var stream: SCStream?
  private var recordingOutput: SCRecordingOutput?
  private var outputURL: URL?
  private var finishContinuation: CheckedContinuation<URL, Error>?
  private var presenterOverlayHandler: ((Bool) -> Void)?
  private var errorHandler: ((Error) -> Void)?
  private let sampleOutput = SampleStreamOutput()
  private let sampleQueue = DispatchQueue(label: "CaptureThis.SampleOutput")

  func startRecording(
    filter: SCContentFilter,
    configuration: SCStreamConfiguration,
    outputURL: URL,
    presenterOverlayHandler: @escaping (Bool) -> Void,
    errorHandler: @escaping (Error) -> Void
  ) async throws {
    if stream != nil {
      try await stopAndReset()
    }

    self.outputURL = outputURL
    self.presenterOverlayHandler = presenterOverlayHandler
    self.errorHandler = errorHandler

    let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
    let recordingConfig = SCRecordingOutputConfiguration()
    let outputFileType = preferredFileType(from: recordingConfig.availableOutputFileTypes)
    let videoCodec = preferredVideoCodec(from: recordingConfig.availableVideoCodecTypes)
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

  func stopRecording() async throws -> URL {
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
  func stream(_: SCStream, didStopWithError error: Error) {
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

  func stream(_: SCStream, outputEffectDidStart didStart: Bool) {
    presenterOverlayHandler?(didStart)
  }
}

extension CaptureService: SCRecordingOutputDelegate {
  func recordingOutputDidFinishRecording(_: SCRecordingOutput) {
    if let outputURL {
      finishContinuation?.resume(returning: outputURL)
      finishContinuation = nil
    }
    Task { [weak self] in
      try? await self?.stopAndReset()
    }
  }

  func recordingOutput(_: SCRecordingOutput, didFailWithError error: Error) {
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
  private func preferredFileType(from available: [AVFileType]) -> AVFileType {
    if available.contains(.mp4) {
      return .mp4
    }
    if available.contains(.mov) {
      return .mov
    }
    return available.first ?? .mp4
  }

  private func preferredVideoCodec(from available: [AVVideoCodecType]) -> AVVideoCodecType {
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
  ) {
    // Intentionally discard samples; keeps the stream outputs attached.
  }
}
