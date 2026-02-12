import AVFoundation
import Foundation
import ScreenCaptureKit

public final class CaptureService: NSObject, CaptureServicing {
  private var stream: SCStream?
  private var recordingOutput: SCRecordingOutput?
  private var activeSegmentURL: URL?

  private var segmentURLs: [URL] = []
  private var segmentIndex = 0
  private var baseOutputURL: URL?
  private var recordingOptions: CaptureRecordingOptions?
  private var resolvedOutputFileType: AVFileType?
  private var resolvedVideoCodec: AVVideoCodecType?

  private var finishContinuation: CheckedContinuation<Void, Error>?
  private var pauseContinuation: CheckedContinuation<Void, Error>?
  private var discardContinuation: CheckedContinuation<Void, Error>?
  private var isTransitioningOutput = false

  private var presenterOverlayHandler: ((Bool) -> Void)?
  private var errorHandler: ((Error) -> Void)?

  private let sampleOutput = SampleStreamOutput()
  private let sampleQueue = DispatchQueue(label: "CaptureThis.SampleOutput")
  private let stitcher: SegmentStitcher
  private let fileManager: FileManager

  override public convenience init() {
    self.init(stitcher: SegmentStitcher(), fileManager: .default)
  }

  init(stitcher: SegmentStitcher, fileManager: FileManager = .default) {
    self.stitcher = stitcher
    self.fileManager = fileManager
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

    resetSegmentState()
    presenterOverlayHandler = handlers.presenterOverlay
    errorHandler = handlers.error
    recordingOptions = options
    baseOutputURL = outputURL

    let stream = SCStream(filter: filter, configuration: configuration, delegate: self)

    do {
      let (recordingOutput, segmentURL) = try makeRecordingOutput(forSegmentIndex: 0)
      activeSegmentURL = segmentURL

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
      segmentIndex = 0
    } catch {
      try? await stopAndReset()
      throw error
    }
  }

  public func pauseRecording() async throws {
    guard let stream, let recordingOutput, !isTransitioningOutput else {
      throw AppError.captureFailed
    }

    isTransitioningOutput = true
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      pauseContinuation = continuation
      do {
        try stream.removeRecordingOutput(recordingOutput)
      } catch {
        pauseContinuation = nil
        isTransitioningOutput = false
        continuation.resume(throwing: error)
      }
    }
  }

  public func resumeRecording() throws {
    guard let stream, recordingOutput == nil, !isTransitioningOutput else {
      throw AppError.captureFailed
    }

    isTransitioningOutput = true
    segmentIndex += 1

    do {
      let (newOutput, segmentURL) = try makeRecordingOutput(forSegmentIndex: segmentIndex)
      activeSegmentURL = segmentURL
      try stream.addRecordingOutput(newOutput)
      recordingOutput = newOutput
      isTransitioningOutput = false
    } catch {
      segmentIndex = max(segmentIndex - 1, 0)
      activeSegmentURL = nil
      isTransitioningOutput = false
      throw error
    }
  }

  public func stopRecording() async throws -> URL {
    guard stream != nil, !isTransitioningOutput else {
      throw AppError.captureFailed
    }

    if let stream, let recordingOutput {
      isTransitioningOutput = true
      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        finishContinuation = continuation
        do {
          try stream.removeRecordingOutput(recordingOutput)
        } catch {
          finishContinuation = nil
          isTransitioningOutput = false
          continuation.resume(throwing: error)
        }
      }
    }

    guard let baseOutputURL, let outputFileType = resolvedOutputFileType else {
      throw AppError.captureFailed
    }

    let segments = segmentURLs
    do {
      let result = try await stitcher.stitch(
        segments: segments,
        destination: baseOutputURL,
        outputFileType: outputFileType
      )
      try await stopAndReset()
      return result
    } catch {
      try? await stopAndReset(clearSegmentState: false)
      throw error
    }
  }

  public func discardRecording() async {
    if let stream, let recordingOutput, !isTransitioningOutput {
      isTransitioningOutput = true
      do {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
          discardContinuation = continuation
          do {
            try stream.removeRecordingOutput(recordingOutput)
          } catch {
            discardContinuation = nil
            isTransitioningOutput = false
            continuation.resume(throwing: error)
          }
        }
      } catch {
        recordingOutputDidFail(error)
      }
    }

    let urlsToDelete = Set(segmentURLs + [activeSegmentURL].compactMap(\.self))
    for url in urlsToDelete {
      try? fileManager.removeItem(at: url)
    }

    try? await stopAndReset()
  }

  public func recoverPartialRecording() async -> URL? {
    if let baseOutputURL, fileSize(at: baseOutputURL) > 0 {
      resetSegmentState()
      return baseOutputURL
    }

    guard let baseOutputURL,
          let outputFileType = resolvedOutputFileType,
          !segmentURLs.isEmpty
    else {
      resetSegmentState()
      return nil
    }

    do {
      let recovered = try await stitcher.stitch(
        segments: segmentURLs,
        destination: baseOutputURL,
        outputFileType: outputFileType
      )
      resetSegmentState()
      return recovered
    } catch {
      let fallback = segmentURLs
        .sorted { fileSize(at: $0) > fileSize(at: $1) }
        .first(where: { fileSize(at: $0) > 0 })
      resetSegmentState()
      return fallback
    }
  }
}

extension CaptureService {
  func makeRecordingOutput(forSegmentIndex index: Int) throws -> (SCRecordingOutput, URL) {
    guard let originalBaseOutputURL = baseOutputURL else {
      throw AppError.captureFailed
    }

    let recordingConfig = SCRecordingOutputConfiguration()
    let outputFileType: AVFileType
    let videoCodec: AVVideoCodecType

    if let resolvedOutputFileType, let resolvedVideoCodec {
      outputFileType = resolvedOutputFileType
      videoCodec = resolvedVideoCodec
    } else {
      outputFileType = preferredFileType(
        from: recordingConfig.availableOutputFileTypes,
        preferred: recordingOptions?.preferredFileType
      )
      videoCodec = preferredVideoCodec(
        from: recordingConfig.availableVideoCodecTypes,
        preferred: recordingOptions?.preferredVideoCodec
      )
      resolvedOutputFileType = outputFileType
      resolvedVideoCodec = videoCodec
      baseOutputURL = originalBaseOutputURL
        .deletingPathExtension()
        .appendingPathExtension(fileExtension(for: outputFileType))
    }

    guard let resolvedBaseOutputURL = baseOutputURL else {
      throw AppError.captureFailed
    }

    let segmentURL = segmentURL(for: index, baseOutputURL: resolvedBaseOutputURL, fileType: outputFileType)
    if fileManager.fileExists(atPath: segmentURL.path) {
      try? fileManager.removeItem(at: segmentURL)
    }

    recordingConfig.outputURL = segmentURL
    recordingConfig.outputFileType = outputFileType
    recordingConfig.videoCodecType = videoCodec

    let output = SCRecordingOutput(configuration: recordingConfig, delegate: self)
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

  func finalizeActiveSegment() {
    if let activeSegmentURL {
      segmentURLs.append(activeSegmentURL)
      self.activeSegmentURL = nil
    }
    recordingOutput = nil
  }

  func recordingOutputDidFail(_ error: Error) {
    let hadContinuation = pauseContinuation != nil || finishContinuation != nil || discardContinuation != nil

    pauseContinuation?.resume(throwing: error)
    finishContinuation?.resume(throwing: error)
    discardContinuation?.resume(throwing: error)

    pauseContinuation = nil
    finishContinuation = nil
    discardContinuation = nil
    isTransitioningOutput = false

    if !hadContinuation {
      errorHandler?(error)
    }

    Task { [weak self] in
      try? await self?.stopAndReset(clearSegmentState: false)
    }
  }

  func handleOutputEffectDidStart(_ didStart: Bool) {
    presenterOverlayHandler?(didStart)
  }

  func handleRecordingOutputDidFinish() {
    if let pauseContinuation {
      self.pauseContinuation = nil
      finalizeActiveSegment()
      isTransitioningOutput = false
      pauseContinuation.resume()
      return
    }

    if let finishContinuation {
      self.finishContinuation = nil
      finalizeActiveSegment()
      isTransitioningOutput = false
      finishContinuation.resume()
      return
    }

    if let discardContinuation {
      self.discardContinuation = nil
      finalizeActiveSegment()
      isTransitioningOutput = false
      discardContinuation.resume()
      return
    }

    finalizeActiveSegment()
    isTransitioningOutput = false
  }

  func handleStreamDidStop(with error: Error) {
    let hadContinuation = pauseContinuation != nil || finishContinuation != nil || discardContinuation != nil

    pauseContinuation?.resume(throwing: error)
    finishContinuation?.resume(throwing: error)
    discardContinuation?.resume(throwing: error)

    pauseContinuation = nil
    finishContinuation = nil
    discardContinuation = nil
    isTransitioningOutput = false

    if !hadContinuation {
      errorHandler?(error)
    }

    stream = nil
    recordingOutput = nil
    activeSegmentURL = nil
  }

  func stopAndReset(clearSegmentState: Bool = true) async throws {
    if let stream {
      try? stream.removeStreamOutput(sampleOutput, type: .screen)
      try? stream.removeStreamOutput(sampleOutput, type: .audio)
      try? stream.removeStreamOutput(sampleOutput, type: .microphone)
      if let recordingOutput {
        try? stream.removeRecordingOutput(recordingOutput)
      }
      try? await stream.stopCapture()
    }

    stream = nil
    recordingOutput = nil
    activeSegmentURL = nil
    isTransitioningOutput = false
    pauseContinuation = nil
    finishContinuation = nil
    discardContinuation = nil

    if clearSegmentState {
      resetSegmentState()
    }
  }

  func resetSegmentState() {
    segmentURLs = []
    segmentIndex = 0
    baseOutputURL = nil
    recordingOptions = nil
    resolvedOutputFileType = nil
    resolvedVideoCodec = nil
    activeSegmentURL = nil
  }

  func fileSize(at url: URL) -> Int64 {
    guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
          let size = attributes[.size] as? NSNumber
    else {
      return 0
    }
    return size.int64Value
  }
}
