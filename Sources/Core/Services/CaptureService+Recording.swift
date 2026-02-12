import AVFoundation
import Foundation
import ScreenCaptureKit

extension CaptureService: CaptureServicing {
  public func startRecording(
    filter: SCContentFilter,
    configuration: SCStreamConfiguration,
    outputURL: URL,
    options: CaptureRecordingOptions,
    handlers: CaptureRecordingHandlers
  ) async throws {
    if withStateLock({ stream != nil }) {
      try await stopAndReset()
    }

    withStateLock {
      resetSegmentStateLocked()
      presenterOverlayHandler = handlers.presenterOverlay
      errorHandler = handlers.error
      recordingOptions = options
      baseOutputURL = outputURL
      phase = .idle
    }

    let newStream = streamBuilder.makeStream(
      filter: filter,
      configuration: configuration,
      delegate: self
    )

    do {
      let (newOutput, segmentURL) = try makeRecordingOutput(forSegmentIndex: 0)

      try newStream.addStreamOutput(sampleOutput, type: .screen, sampleHandlerQueue: sampleQueue)
      if configuration.capturesAudio {
        try newStream.addStreamOutput(sampleOutput, type: .audio, sampleHandlerQueue: sampleQueue)
      }
      if configuration.captureMicrophone {
        try newStream.addStreamOutput(sampleOutput, type: .microphone, sampleHandlerQueue: sampleQueue)
      }

      try newStream.addRecordingOutput(newOutput)
      try await newStream.startCapture()

      withStateLock {
        stream = newStream
        recordingOutput = newOutput
        activeSegmentURL = segmentURL
        segmentIndex = 0
        phase = .recording
      }
    } catch {
      try? await stopAndReset()
      throw error
    }
  }

  public func pauseRecording() async throws {
    let (activeStream, activeOutput) = try withStateLock {
      guard phase == .recording,
            let stream,
            let recordingOutput
      else {
        throw AppError.captureFailed
      }
      phase = .pausing
      return (stream, recordingOutput)
    }

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      withStateLock {
        pauseContinuation = continuation
      }

      do {
        try activeStream.removeRecordingOutput(activeOutput)
      } catch {
        withStateLock {
          pauseContinuation = nil
          phase = .recording
        }
        continuation.resume(throwing: error)
      }
    }
  }

  public func resumeRecording() throws {
    let activeStream = try withStateLock {
      guard phase == .paused,
            let stream,
            recordingOutput == nil
      else {
        throw AppError.captureFailed
      }
      phase = .resuming
      segmentIndex += 1
      return stream
    }

    let nextSegmentIndex = withStateLock { segmentIndex }

    do {
      let (newOutput, segmentURL) = try makeRecordingOutput(forSegmentIndex: nextSegmentIndex)
      try activeStream.addRecordingOutput(newOutput)

      withStateLock {
        recordingOutput = newOutput
        activeSegmentURL = segmentURL
        phase = .recording
      }
    } catch {
      withStateLock {
        segmentIndex = max(segmentIndex - 1, 0)
        activeSegmentURL = nil
        recordingOutput = nil
        phase = .paused
      }
      throw error
    }
  }

  public func stopRecording() async throws -> URL {
    let mode = try resolveStopMode()
    try await finalizeStopIfNeeded(mode)

    let stitchInput = try stopStitchInput()
    do {
      let stitchedURL = try await stitcher.stitch(
        segments: stitchInput.segments,
        destination: stitchInput.baseOutputURL,
        outputFileType: stitchInput.outputFileType
      )
      try await stopAndReset()
      return stitchedURL
    } catch {
      try? await stopAndReset(clearSegmentState: false)
      throw error
    }
  }

  public func discardRecording() async {
    let mode = resolveDiscardMode()
    guard case .noOp = mode else {
      await finalizeDiscardIfNeeded(mode)
      removeDiscardedSegments()
      try? await stopAndReset()
      return
    }
  }

  public func recoverPartialRecording() async -> URL? {
    let (baseURL, outputFileType, segments) = withStateLock {
      (baseOutputURL, resolvedOutputFileType, segmentURLs)
    }

    if let baseURL, fileSize(at: baseURL) > 0 {
      withStateLock {
        resetSegmentStateLocked()
      }
      return baseURL
    }

    guard let baseURL,
          let outputFileType,
          !segments.isEmpty
    else {
      withStateLock {
        resetSegmentStateLocked()
      }
      return nil
    }

    do {
      let recovered = try await stitcher.stitch(
        segments: segments,
        destination: baseURL,
        outputFileType: outputFileType
      )
      withStateLock {
        resetSegmentStateLocked()
      }
      return recovered
    } catch {
      let fallback = segments
        .sorted { fileSize(at: $0) > fileSize(at: $1) }
        .first(where: { fileSize(at: $0) > 0 })
      withStateLock {
        resetSegmentStateLocked()
      }
      return fallback
    }
  }
}

extension CaptureService {
  func resolveStopMode() throws -> CaptureStopMode {
    try withStateLock {
      switch phase {
      case .recording:
        guard let stream,
              let recordingOutput
        else {
          throw AppError.captureFailed
        }
        phase = .stopping
        return .finalize(stream, recordingOutput)
      case .paused:
        guard stream != nil else {
          throw AppError.captureFailed
        }
        phase = .stopping
        return .stitchOnly
      default:
        throw AppError.captureFailed
      }
    }
  }

  func finalizeStopIfNeeded(_ mode: CaptureStopMode) async throws {
    guard case let .finalize(activeStream, activeOutput) = mode else {
      return
    }

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      withStateLock {
        finishContinuation = continuation
      }

      do {
        try activeStream.removeRecordingOutput(activeOutput)
      } catch {
        withStateLock {
          finishContinuation = nil
          phase = .recording
        }
        continuation.resume(throwing: error)
      }
    }
  }

  func stopStitchInput() throws -> CaptureStitchInput {
    try withStateLock {
      guard let baseOutputURL,
            let outputFileType = resolvedOutputFileType
      else {
        throw AppError.captureFailed
      }

      return CaptureStitchInput(
        baseOutputURL: baseOutputURL,
        outputFileType: outputFileType,
        segments: segmentURLs
      )
    }
  }

  func resolveDiscardMode() -> CaptureDiscardMode {
    withStateLock {
      switch phase {
      case .recording:
        guard let stream,
              let recordingOutput
        else {
          return .noOp
        }
        phase = .discarding
        return .finalize(stream, recordingOutput)
      case .paused:
        guard stream != nil else {
          return .noOp
        }
        phase = .discarding
        return .stopOnly
      default:
        return .noOp
      }
    }
  }

  func finalizeDiscardIfNeeded(_ mode: CaptureDiscardMode) async {
    guard case let .finalize(activeStream, activeOutput) = mode else {
      return
    }

    do {
      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        withStateLock {
          discardContinuation = continuation
        }

        do {
          try activeStream.removeRecordingOutput(activeOutput)
        } catch {
          withStateLock {
            discardContinuation = nil
            phase = .recording
          }
          continuation.resume(throwing: error)
        }
      }
    } catch {
      recordingOutputDidFail(error)
    }
  }

  func removeDiscardedSegments() {
    let urlsToDelete = withStateLock { Set(segmentURLs + [activeSegmentURL].compactMap(\.self)) }
    for url in urlsToDelete {
      try? fileManager.removeItem(at: url)
    }
  }
}
