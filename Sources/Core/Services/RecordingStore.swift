import Foundation

public enum RecordingStore {
  private static let maxItems = 20

  public static func load() -> [Recording] {
    let url = storageURL()
    guard let data = try? Data(contentsOf: url) else { return [] }

    do {
      return try JSONDecoder().decode([Recording].self, from: data)
    } catch {
      return []
    }
  }

  public static func add(_ recording: Recording, to list: [Recording]) -> [Recording] {
    var updated = [recording] + list
    if updated.count > maxItems {
      updated = Array(updated.prefix(maxItems))
    }
    return updated
  }

  public static func save(_ recordings: [Recording]) {
    let url = storageURL()
    let folder = url.deletingLastPathComponent()
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

    do {
      let data = try JSONEncoder().encode(recordings)
      try data.write(to: url, options: .atomic)
    } catch {
      return
    }
  }

  private static func storageURL() -> URL {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    let folder = (appSupport ?? FileManager.default.homeDirectoryForCurrentUser)
      .appendingPathComponent("CaptureThis", isDirectory: true)
    return folder.appendingPathComponent("recordings.json")
  }
}
