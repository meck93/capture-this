import Foundation
import ScreenCaptureKit

protocol CaptureStreamControlling: AnyObject {
  func addStreamOutput(_ output: SCStreamOutput, type: SCStreamOutputType, sampleHandlerQueue: DispatchQueue?) throws
  func removeStreamOutput(_ output: SCStreamOutput, type: SCStreamOutputType) throws
  func addRecordingOutput(_ output: any CaptureRecordingOutputControlling) throws
  func removeRecordingOutput(_ output: any CaptureRecordingOutputControlling) throws
  func startCapture() async throws
  func stopCapture() async throws
}

protocol CaptureRecordingOutputControlling: AnyObject {}

protocol CaptureStreamBuilding {
  func makeStream(
    filter: SCContentFilter,
    configuration: SCStreamConfiguration,
    delegate: SCStreamDelegate?
  ) -> any CaptureStreamControlling
}

protocol CaptureRecordingOutputBuilding {
  func makeRecordingOutput(
    configuration: SCRecordingOutputConfiguration,
    delegate: SCRecordingOutputDelegate
  ) -> any CaptureRecordingOutputControlling
}

final class ScreenCaptureStreamBuilder: CaptureStreamBuilding {
  func makeStream(
    filter: SCContentFilter,
    configuration: SCStreamConfiguration,
    delegate: SCStreamDelegate?
  ) -> any CaptureStreamControlling {
    ScreenCaptureStreamController(stream: SCStream(filter: filter, configuration: configuration, delegate: delegate))
  }
}

final class ScreenCaptureRecordingOutputBuilder: CaptureRecordingOutputBuilding {
  func makeRecordingOutput(
    configuration: SCRecordingOutputConfiguration,
    delegate: SCRecordingOutputDelegate
  ) -> any CaptureRecordingOutputControlling {
    ScreenCaptureRecordingOutputController(
      recordingOutput: SCRecordingOutput(configuration: configuration, delegate: delegate)
    )
  }
}

final class ScreenCaptureStreamController: CaptureStreamControlling {
  private let stream: SCStream

  init(stream: SCStream) {
    self.stream = stream
  }

  func addStreamOutput(_ output: SCStreamOutput, type: SCStreamOutputType, sampleHandlerQueue: DispatchQueue?) throws {
    try stream.addStreamOutput(output, type: type, sampleHandlerQueue: sampleHandlerQueue)
  }

  func removeStreamOutput(_ output: SCStreamOutput, type: SCStreamOutputType) throws {
    try stream.removeStreamOutput(output, type: type)
  }

  func addRecordingOutput(_ output: any CaptureRecordingOutputControlling) throws {
    guard let output = output as? ScreenCaptureRecordingOutputController else {
      throw AppError.captureFailed
    }
    try stream.addRecordingOutput(output.recordingOutput)
  }

  func removeRecordingOutput(_ output: any CaptureRecordingOutputControlling) throws {
    guard let output = output as? ScreenCaptureRecordingOutputController else {
      throw AppError.captureFailed
    }
    try stream.removeRecordingOutput(output.recordingOutput)
  }

  func startCapture() async throws {
    try await stream.startCapture()
  }

  func stopCapture() async throws {
    try await stream.stopCapture()
  }
}

final class ScreenCaptureRecordingOutputController: CaptureRecordingOutputControlling {
  let recordingOutput: SCRecordingOutput

  init(recordingOutput: SCRecordingOutput) {
    self.recordingOutput = recordingOutput
  }
}
