import AVFoundation
import Foundation

#if DEBUG
  extension CaptureService {
    func installTestSession(
      stream: any CaptureStreamControlling,
      recordingOutput: (any CaptureRecordingOutputControlling)?,
      baseOutputURL: URL,
      outputFileType: AVFileType,
      videoCodec: AVVideoCodecType = .h264,
      segmentURLs: [URL] = [],
      segmentIndex: Int = 0,
      paused: Bool
    ) {
      withStateLock {
        self.stream = stream
        self.recordingOutput = recordingOutput
        self.baseOutputURL = baseOutputURL
        resolvedOutputFileType = outputFileType
        resolvedVideoCodec = videoCodec
        self.segmentURLs = segmentURLs
        self.segmentIndex = segmentIndex
        phase = paused ? .paused : .recording
        activeSegmentURL = nil
      }
    }

    func phaseForTesting() -> String {
      withStateLock {
        phase.rawValue
      }
    }

    func segmentIndexForTesting() -> Int {
      withStateLock {
        segmentIndex
      }
    }
  }
#endif
