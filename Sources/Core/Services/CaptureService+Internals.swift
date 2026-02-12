import AVFoundation
import Foundation
import ScreenCaptureKit

extension CaptureService {
  func makeRecordingOutput(forSegmentIndex index: Int) throws -> (any CaptureRecordingOutputControlling, URL) {
    let (initialBaseOutputURL, options, cachedOutputFileType, cachedVideoCodec) = withStateLock {
      (baseOutputURL, recordingOptions, resolvedOutputFileType, resolvedVideoCodec)
    }

    guard let initialBaseOutputURL else {
      throw AppError.captureFailed
    }

    let recordingConfig = SCRecordingOutputConfiguration()
    let outputFileType: AVFileType
    let videoCodec: AVVideoCodecType

    if let cachedOutputFileType, let cachedVideoCodec {
      outputFileType = cachedOutputFileType
      videoCodec = cachedVideoCodec
    } else {
      outputFileType = preferredFileType(
        from: recordingConfig.availableOutputFileTypes,
        preferred: options?.preferredFileType
      )
      videoCodec = preferredVideoCodec(
        from: recordingConfig.availableVideoCodecTypes,
        preferred: options?.preferredVideoCodec
      )

      withStateLock {
        resolvedOutputFileType = outputFileType
        resolvedVideoCodec = videoCodec
        baseOutputURL = initialBaseOutputURL
          .deletingPathExtension()
          .appendingPathExtension(fileExtension(for: outputFileType))
      }
    }

    let resolvedBaseOutputURL = withStateLock { baseOutputURL }
    guard let resolvedBaseOutputURL else {
      throw AppError.captureFailed
    }

    let segmentURL = segmentURL(for: index, baseOutputURL: resolvedBaseOutputURL, fileType: outputFileType)
    if fileManager.fileExists(atPath: segmentURL.path) {
      try? fileManager.removeItem(at: segmentURL)
    }

    recordingConfig.outputURL = segmentURL
    recordingConfig.outputFileType = outputFileType
    recordingConfig.videoCodecType = videoCodec

    let output = recordingOutputBuilder.makeRecordingOutput(configuration: recordingConfig, delegate: self)
    return (output, segmentURL)
  }

  func segmentURL(for index: Int, baseOutputURL: URL, fileType: AVFileType) -> URL {
    let baseNameURL = baseOutputURL.deletingPathExtension()
    let filename = "\(baseNameURL.lastPathComponent)_seg\(index)"
    return baseNameURL
      .deletingLastPathComponent()
      .appendingPathComponent(filename)
      .appendingPathExtension(fileExtension(for: fileType))
  }

  func recordingOutputDidFail(_ error: Error) {
    let (continuations, fallbackHandler) = withStateLock { () -> (CaptureContinuations, ((Error) -> Void)?) in
      let continuations = drainContinuationsLocked()
      let handler = continuations.hasActive ? nil : errorHandler
      phase = .idle
      return (continuations, handler)
    }

    resume(continuations: continuations, throwing: error)
    fallbackHandler?(error)

    Task { [weak self] in
      try? await self?.stopAndReset(clearSegmentState: false)
    }
  }

  func handleOutputEffectDidStart(_ didStart: Bool) {
    let handler = withStateLock { presenterOverlayHandler }
    handler?(didStart)
  }

  func handleRecordingOutputDidFinish() {
    let action: CaptureCompletionAction = withStateLock {
      finalizeActiveSegmentLocked()

      if let pauseContinuation {
        self.pauseContinuation = nil
        phase = .paused
        return .pause(pauseContinuation)
      }

      if let finishContinuation {
        self.finishContinuation = nil
        return .stop(finishContinuation)
      }

      if let discardContinuation {
        self.discardContinuation = nil
        return .discard(discardContinuation)
      }

      if phase == .pausing {
        phase = .paused
      }

      return .none
    }

    switch action {
    case let .pause(continuation), let .stop(continuation), let .discard(continuation):
      continuation.resume()
    case .none:
      break
    }
  }

  func handleStreamDidStop(with error: Error) {
    let (continuations, fallbackHandler) = withStateLock { () -> (CaptureContinuations, ((Error) -> Void)?) in
      let continuations = drainContinuationsLocked()
      let handler = continuations.hasActive ? nil : errorHandler
      stream = nil
      recordingOutput = nil
      activeSegmentURL = nil
      phase = .idle
      return (continuations, handler)
    }

    resume(continuations: continuations, throwing: error)
    fallbackHandler?(error)
  }

  func stopAndReset(clearSegmentState: Bool = true) async throws {
    let (streamToStop, outputToRemove) = withStateLock {
      let currentStream = stream
      let currentRecordingOutput = recordingOutput

      stream = nil
      recordingOutput = nil
      activeSegmentURL = nil
      phase = .idle

      _ = drainContinuationsLocked()

      if clearSegmentState {
        resetSegmentStateLocked()
      }

      return (currentStream, currentRecordingOutput)
    }

    if let streamToStop {
      try? streamToStop.removeStreamOutput(sampleOutput, type: .screen)
      try? streamToStop.removeStreamOutput(sampleOutput, type: .audio)
      try? streamToStop.removeStreamOutput(sampleOutput, type: .microphone)
      if let outputToRemove {
        try? streamToStop.removeRecordingOutput(outputToRemove)
      }
      try? await streamToStop.stopCapture()
    }
  }

  func fileSize(at url: URL) -> Int64 {
    guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
          let size = attributes[.size] as? NSNumber
    else {
      return 0
    }
    return size.int64Value
  }

  @discardableResult
  func withStateLock<T>(_ body: () throws -> T) rethrows -> T {
    stateLock.lock()
    defer { stateLock.unlock() }
    return try body()
  }

  func finalizeActiveSegmentLocked() {
    if let activeSegmentURL {
      segmentURLs.append(activeSegmentURL)
      self.activeSegmentURL = nil
    }
    recordingOutput = nil
  }

  func resetSegmentStateLocked() {
    segmentURLs = []
    segmentIndex = 0
    baseOutputURL = nil
    recordingOptions = nil
    resolvedOutputFileType = nil
    resolvedVideoCodec = nil
    activeSegmentURL = nil
  }

  func drainContinuationsLocked() -> CaptureContinuations {
    let continuations = CaptureContinuations(
      pause: pauseContinuation,
      finish: finishContinuation,
      discard: discardContinuation
    )
    pauseContinuation = nil
    finishContinuation = nil
    discardContinuation = nil
    return continuations
  }

  func resume(continuations: CaptureContinuations, throwing error: Error) {
    continuations.pause?.resume(throwing: error)
    continuations.finish?.resume(throwing: error)
    continuations.discard?.resume(throwing: error)
  }
}
