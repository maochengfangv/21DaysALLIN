import Foundation
import React

@objc(HotUpdateBridge)
final class HotUpdateBridge: NSObject {
  @objc
  static func requiresMainQueueSetup() -> Bool {
    false
  }

  @objc(getCurrentBundlePath:rejecter:)
  func getCurrentBundlePath(
    _ resolve: RCTPromiseResolveBlock,
    rejecter reject: RCTPromiseRejectBlock
  ) {
    resolve(HotUpdateBundleStore.currentBundlePath())
  }

  @objc(setCurrentBundlePath:resolver:rejecter:)
  func setCurrentBundlePath(
    _ bundlePath: String,
    resolver resolve: RCTPromiseResolveBlock,
    rejecter reject: RCTPromiseRejectBlock
  ) {
    HotUpdateBundleStore.setCurrentBundlePath(bundlePath)
    resolve(nil)
  }

  @objc(clearCurrentBundlePath:rejecter:)
  func clearCurrentBundlePath(
    _ resolve: RCTPromiseResolveBlock,
    rejecter reject: RCTPromiseRejectBlock
  ) {
    HotUpdateBundleStore.clearCurrentBundlePath()
    resolve(nil)
  }

  @objc(getEmbeddedBundlePath:rejecter:)
  func getEmbeddedBundlePath(
    _ resolve: RCTPromiseResolveBlock,
    rejecter reject: RCTPromiseRejectBlock
  ) {
    resolve(Bundle.main.path(forResource: "main", ofType: "jsbundle"))
  }

  @objc(reloadBundle:resolver:rejecter:)
  func reloadBundle(
    _ bundlePath: String?,
    resolver resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    let nextBundleURL: URL?

    if let bundlePath, !bundlePath.isEmpty {
      HotUpdateBundleStore.setCurrentBundlePath(bundlePath)
      nextBundleURL = URL(fileURLWithPath: bundlePath)
    } else if let storedURL = HotUpdateBundleStore.currentBundleURL() {
      nextBundleURL = storedURL
    } else {
      HotUpdateBundleStore.clearCurrentBundlePath()
      nextBundleURL = Bundle.main.url(forResource: "main", withExtension: "jsbundle")
    }

    guard let nextBundleURL else {
      reject("E_BUNDLE_URL", "未找到可用的 JS bundle", nil)
      return
    }

    RCTReloadCommandSetBundleURL(nextBundleURL)
    DispatchQueue.main.async {
      RCTTriggerReloadCommandListeners("Hot update bundle reload")
      resolve(nil)
    }
  }

  @objc(getAppVersion:rejecter:)
  func getAppVersion(
    _ resolve: RCTPromiseResolveBlock,
    rejecter reject: RCTPromiseRejectBlock
  ) {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    resolve(version)
  }

  @objc(getBuildNumber:rejecter:)
  func getBuildNumber(
    _ resolve: RCTPromiseResolveBlock,
    rejecter reject: RCTPromiseRejectBlock
  ) {
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    resolve(build)
  }
}
