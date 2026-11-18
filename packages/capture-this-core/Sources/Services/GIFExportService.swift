import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct GIFExportPolicy: Equatable, Sendable {
  public let maxDuration: TimeInterval
  public let targetWidth: CGFloat
  public let targetFramesPerSecond: Double

  public static let standard = GIFExportPolicy(
    maxDuration: 10,
    targetWidth: 720,
    targetFramesPerSecond: 12
  )

  public init(
    maxDuration: TimeInterval,
    targetWidth: CGFloat,
    targetFramesPerSecond: Double
  ) {
    self.maxDuration = maxDuration
    self.targetWidth = targetWidth
    self.targetFramesPerSecond = targetFramesPerSecond
  }

  public init(quality: GIFExportQuality) {
    self.init(
      maxDuration: Self.standard.maxDuration,
      targetWidth: CGFloat(quality.targetWidth),
      targetFramesPerSecond: quality.framesPerSecond
    )
  }
}

public enum GIFExportError: LocalizedError, Equatable {
  case durationUnavailable
  case clipTooLong(duration: TimeInterval, maxDuration: TimeInterval)
  case noVideoTrack
  case imageDestinationUnavailable
  case imageEncodingFailed

  public var errorDescription: String? {
    switch self {
    case .durationUnavailable:
      "Unable to read the recording duration."
    case let .clipTooLong(duration, maxDuration):
      "GIF export supports clips up to \(Self.format(maxDuration)); this recording is \(Self.format(duration))."
    case .noVideoTrack:
      "The recording does not contain a video track."
    case .imageDestinationUnavailable:
      "Unable to create the GIF file."
    case .imageEncodingFailed:
      "Unable to encode the GIF."
    }
  }

  private static func format(_ duration: TimeInterval) -> String {
    let rounded = (duration * 10).rounded() / 10
    return "\(rounded)s"
  }
}

public final class GIFExportService {
  private let fileManager: FileManager
  private let policy: GIFExportPolicy

  public init(fileManager: FileManager = .default, policy: GIFExportPolicy = .standard) {
    self.fileManager = fileManager
    self.policy = policy
  }

  public func export(recording: Recording) async throws -> URL {
    let asset = AVURLAsset(url: recording.url)
    let duration = try await resolvedDuration(for: recording, asset: asset)
    try validate(duration: duration)

    let outputURL = uniqueDestinationURL(for: recording.url)
    let frameCount = max(1, Int((duration * policy.targetFramesPerSecond).rounded(.up)))
    let frameDelay = 1 / policy.targetFramesPerSecond
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero

    let size = try await scaledVideoSize(for: asset)
    generator.maximumSize = size

    guard let destination = CGImageDestinationCreateWithURL(
      outputURL as CFURL,
      UTType.gif.identifier as CFString,
      frameCount,
      nil
    ) else {
      throw GIFExportError.imageDestinationUnavailable
    }

    CGImageDestinationSetProperties(destination, [
      kCGImagePropertyGIFDictionary: [
        kCGImagePropertyGIFLoopCount: 0
      ]
    ] as CFDictionary)

    let frameProperties = [
      kCGImagePropertyGIFDictionary: [
        kCGImagePropertyGIFDelayTime: frameDelay
      ]
    ] as CFDictionary

    for frameIndex in 0 ..< frameCount {
      let seconds = min(Double(frameIndex) / policy.targetFramesPerSecond, max(duration - 0.001, 0))
      let time = CMTime(seconds: seconds, preferredTimescale: 600)
      let image = try generator.copyCGImage(at: time, actualTime: nil)
      CGImageDestinationAddImage(destination, image, frameProperties)
    }

    guard CGImageDestinationFinalize(destination) else {
      try? fileManager.removeItem(at: outputURL)
      throw GIFExportError.imageEncodingFailed
    }

    return outputURL
  }

  public func uniqueDestinationURL(for videoURL: URL) -> URL {
    let directory = videoURL.deletingLastPathComponent()
    let baseName = videoURL.deletingPathExtension().lastPathComponent
    var candidate = directory.appendingPathComponent(baseName).appendingPathExtension("gif")
    var index = 2

    while fileManager.fileExists(atPath: candidate.path) {
      candidate = directory
        .appendingPathComponent("\(baseName)-\(index)")
        .appendingPathExtension("gif")
      index += 1
    }

    return candidate
  }

  private func resolvedDuration(for recording: Recording, asset: AVURLAsset) async throws -> TimeInterval {
    if let duration = recording.duration, duration > 0 {
      return duration
    }

    let assetDuration = try await asset.load(.duration)
    guard assetDuration.isNumeric, assetDuration.seconds > 0 else {
      throw GIFExportError.durationUnavailable
    }
    return assetDuration.seconds
  }

  private func validate(duration: TimeInterval) throws {
    guard duration <= policy.maxDuration else {
      throw GIFExportError.clipTooLong(duration: duration, maxDuration: policy.maxDuration)
    }
  }

  private func scaledVideoSize(for asset: AVURLAsset) async throws -> CGSize {
    guard let track = try await asset.loadTracks(withMediaType: .video).first else {
      throw GIFExportError.noVideoTrack
    }

    let naturalSize = try await track.load(.naturalSize)
    let transform = try await track.load(.preferredTransform)
    let transformed = naturalSize.applying(transform)
    let width = abs(transformed.width)
    let height = abs(transformed.height)

    guard width > 0, height > 0 else {
      throw GIFExportError.noVideoTrack
    }

    let scale = min(1, policy.targetWidth / width)
    return CGSize(width: (width * scale).rounded(), height: (height * scale).rounded())
  }
}
