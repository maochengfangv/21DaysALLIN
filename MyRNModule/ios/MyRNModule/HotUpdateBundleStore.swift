import Foundation

enum HotUpdateBundleStore {
  private static let bundlePathKey = "hot_update_current_bundle_path"

  static func currentBundlePath() -> String? {
    guard let path = UserDefaults.standard.string(forKey: bundlePathKey) else {
      return nil
    }

    if FileManager.default.fileExists(atPath: path) {
      return path
    }

    clearCurrentBundlePath()
    return nil
  }

  static func currentBundleURL() -> URL? {
    guard let path = currentBundlePath() else {
      return nil
    }
    return URL(fileURLWithPath: path)
  }

  static func setCurrentBundlePath(_ path: String) {
    UserDefaults.standard.set(path, forKey: bundlePathKey)
  }

  static func clearCurrentBundlePath() {
    UserDefaults.standard.removeObject(forKey: bundlePathKey)
  }
}
