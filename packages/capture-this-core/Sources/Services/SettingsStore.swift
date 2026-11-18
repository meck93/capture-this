import Foundation

public enum SettingsStore {
  private static let settingsKey = "CaptureThis.RecordingSettings"

  public static func load() -> RecordingSettings {
    guard let data = UserDefaults.standard.data(forKey: settingsKey) else {
      return RecordingSettings()
    }
    do {
      return try JSONDecoder().decode(RecordingSettings.self, from: data)
    } catch {
      return RecordingSettings()
    }
  }

  public static func save(_ settings: RecordingSettings) {
    guard let data = try? JSONEncoder().encode(settings) else { return }
    UserDefaults.standard.set(data, forKey: settingsKey)
  }
}
