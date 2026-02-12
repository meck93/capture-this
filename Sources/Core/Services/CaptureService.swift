import AVFoundation
import Foundation
import ScreenCaptureKit

enum CaptureSessionPhase: String {
  case idle
  case recording
  case pausing
  case paused
  case resuming
  case stopping
  case discarding
}

struct CaptureContinuations {
  var pause: CheckedContinuation<Void, Error>?
  var finish: CheckedContinuation<Void, Error>?
  var discard: CheckedContinuation<Void, Error>?

  var hasActive: Bool {
    pause != nil || finish != nil || discard != nil
  }
}

enum CaptureCompletionAction {
  case pause(CheckedContinuation<Void, Error>)
  case stop(CheckedContinuation<Void, Error>)
  case discard(CheckedContinuation<Void, Error>)
  case none
}

enum CaptureStopMode {
  case finalize(any CaptureStreamControlling, any CaptureRecordingOutputControlling)
  case stitchOnly
}

enum CaptureDiscardMode {
  case finalize(any CaptureStreamControlling, any CaptureRecordingOutputControlling)
  case stopOnly
  case noOp
}

struct CaptureStitchInput {
  let baseOutputURL: URL
  let outputFileType: AVFileType
  let segments: [URL]
}

public final class CaptureService: NSObject {
  var stream: (any CaptureStreamControlling)?
  var recordingOutput: (any CaptureRecordingOutputControlling)?
  var activeSegmentURL: URL?

  var segmentURLs: [URL] = []
  var segmentIndex = 0
  var baseOutputURL: URL?
  var recordingOptions: CaptureRecordingOptions?
  var resolvedOutputFileType: AVFileType?
  var resolvedVideoCodec: AVVideoCodecType?

  var phase: CaptureSessionPhase = .idle
  var finishContinuation: CheckedContinuation<Void, Error>?
  var pauseContinuation: CheckedContinuation<Void, Error>?
  var discardContinuation: CheckedContinuation<Void, Error>?

  var presenterOverlayHandler: ((Bool) -> Void)?
  var errorHandler: ((Error) -> Void)?

  let sampleOutput = SampleStreamOutput()
  let sampleQueue = DispatchQueue(label: "CaptureThis.SampleOutput")
  let stitcher: SegmentStitcher
  let fileManager: FileManager
  let streamBuilder: any CaptureStreamBuilding
  let recordingOutputBuilder: any CaptureRecordingOutputBuilding
  let stateLock = NSLock()

  override public convenience init() {
    self.init(
      stitcher: SegmentStitcher(),
      fileManager: .default,
      streamBuilder: ScreenCaptureStreamBuilder(),
      recordingOutputBuilder: ScreenCaptureRecordingOutputBuilder()
    )
  }

  init(
    stitcher: SegmentStitcher,
    fileManager: FileManager = .default,
    streamBuilder: any CaptureStreamBuilding,
    recordingOutputBuilder: any CaptureRecordingOutputBuilding
  ) {
    self.stitcher = stitcher
    self.fileManager = fileManager
    self.streamBuilder = streamBuilder
    self.recordingOutputBuilder = recordingOutputBuilder
    super.init()
  }
}
