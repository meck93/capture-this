import AVFoundation
import Foundation

protocol SegmentMerging {
  func merge(segments: [URL], destination: URL, outputFileType: AVFileType) async throws -> URL
}

final class AVCompositionSegmentMerger: SegmentMerging {
  func merge(segments: [URL], destination: URL, outputFileType: AVFileType) async throws -> URL {
    let composition = AVMutableComposition()
    var insertionTime = CMTime.zero
    var compositionAudioTrack: AVMutableCompositionTrack?
    guard let compositionVideoTrack = composition.addMutableTrack(
      withMediaType: .video,
      preferredTrackID: kCMPersistentTrackID_Invalid
    ) else {
      throw AppError.fileWriteFailed
    }

    for segmentURL in segments {
      let asset = AVURLAsset(url: segmentURL)
      let duration = try await asset.load(.duration)
      guard duration.isNumeric, duration > .zero else {
        throw AppError.fileWriteFailed
      }

      guard let sourceVideoTrack = try await asset.loadTracks(withMediaType: .video).first else {
        throw AppError.fileWriteFailed
      }

      let timeRange = CMTimeRange(start: .zero, duration: duration)
      try compositionVideoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: insertionTime)

      if let sourceAudioTrack = try await asset.loadTracks(withMediaType: .audio).first {
        if compositionAudioTrack == nil {
          compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
          )
        }
        try compositionAudioTrack?.insertTimeRange(timeRange, of: sourceAudioTrack, at: insertionTime)
      }

      insertionTime = CMTimeAdd(insertionTime, duration)
    }

    guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
      throw AppError.fileWriteFailed
    }

    if FileManager.default.fileExists(atPath: destination.path) {
      try FileManager.default.removeItem(at: destination)
    }

    try await exporter.export(to: destination, as: outputFileType)
    return destination
  }
}

final class SegmentStitcher {
  private let fileManager: FileManager
  private let merger: SegmentMerging

  init(fileManager: FileManager = .default, merger: SegmentMerging = AVCompositionSegmentMerger()) {
    self.fileManager = fileManager
    self.merger = merger
  }

  func stitch(segments: [URL], destination: URL, outputFileType: AVFileType) async throws -> URL {
    guard !segments.isEmpty else {
      throw AppError.fileWriteFailed
    }

    if segments.count == 1 {
      try moveSegment(segments[0], to: destination)
      return destination
    }

    let stitchedURL = try await merger.merge(
      segments: segments,
      destination: destination,
      outputFileType: outputFileType
    )

    for segmentURL in segments {
      try? fileManager.removeItem(at: segmentURL)
    }

    return stitchedURL
  }

  private func moveSegment(_ source: URL, to destination: URL) throws {
    if fileManager.fileExists(atPath: destination.path) {
      try fileManager.removeItem(at: destination)
    }
    if source.standardizedFileURL == destination.standardizedFileURL {
      return
    }
    try fileManager.moveItem(at: source, to: destination)
  }
}
