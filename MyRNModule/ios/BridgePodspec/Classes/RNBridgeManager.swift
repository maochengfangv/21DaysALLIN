import Foundation
import React

@objc public enum RNBundleSource: Int {
  case embedded = 0
  case hotUpdate = 1
  case remoteDebug = 2
}

@objc public enum RNBridgePreloadPolicy: Int {
  case onDemand = 0
  case onAppDidFinishLaunching = 1
  case onHomeDidAppear = 2
}

@objcMembers
public final class RNBridgeManager: NSObject {

  public static let shared = RNBridgeManager()

  public private(set) var bridge: RCTBridge?
  public private(set) var bundleSource: RNBundleSource = .embedded
  public private(set) var isBridgeReady: Bool = false

  public var preloadPolicy: RNBridgePreloadPolicy = .onAppDidFinishLaunching

  public typealias BridgeReadyHandler = (RCTBridge?) -> Void
  private var pendingHandlers: [BridgeReadyHandler] = []
  private var isInitializing: Bool = false

  private override init() {
    super.init()
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleJavaScriptDidLoad(_:)),
      name: NSNotification.Name.RCTJavaScriptDidLoad,
      object: nil
    )
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  // MARK: - Public API

  public func preloadIfNeeded(launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) {
    guard preloadPolicy != .onDemand else { return }
    preloadBridge(launchOptions: launchOptions, completion: nil)
  }

  public func preloadBridge(
    launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil,
    completion: BridgeReadyHandler? = nil
  ) {
    objc_sync_enter(self)
    defer { objc_sync_exit(self) }

    if let bridge, isBridgeReady {
      completion?(bridge)
      return
    }

    if let handler = completion {
      pendingHandlers.append(handler)
    }

    guard !isInitializing else { return }
    isInitializing = true

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let bundleURL = self.resolveActiveBundleURL()
      let bridge = RCTBridge(bundleURL: bundleURL, moduleProvider: nil, launchOptions: launchOptions)
      DispatchQueue.main.async {
        self.bridge = bridge
        self.isBridgeReady = bridge.isLoading == false && bridge.valid
        self.flushPendingHandlersIfNeeded()
      }
    }
  }

  public func ensureBridge(
    launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil,
    completion: @escaping BridgeReadyHandler
  ) {
    objc_sync_enter(self)
    defer { objc_sync_exit(self) }

    if let bridge, isBridgeReady {
      completion(bridge)
      return
    }

    pendingHandlers.append(completion)
    guard !isInitializing else { return }
    isInitializing = true

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      let bundleURL = self.resolveActiveBundleURL()
      let bridge = RCTBridge(bundleURL: bundleURL, moduleProvider: nil, launchOptions: launchOptions)
      DispatchQueue.main.async {
        self.bridge = bridge
        self.isBridgeReady = bridge.isLoading == false && bridge.valid
        self.flushPendingHandlersIfNeeded()
      }
    }
  }

  public func switchBundle(to source: RNBundleSource, customPath: String? = nil) -> Bool {
    let previousURL = resolveActiveBundleURL()
    let nextURL: URL?

    switch source {
    case .embedded:
      nextURL = embeddedBundleURL()
    case .hotUpdate:
      nextURL = hotUpdateBundleURL() ?? embeddedBundleURL()
    case .remoteDebug:
      #if DEBUG
      nextURL = RCTBundleURLProvider.sharedSettings().jsBundleURL(forBundleRoot: "index")
      #else
      nextURL = nil
      #endif
    }

    if let custom = customPath, source == .hotUpdate {
      let candidate = URL(fileURLWithPath: custom)
      if FileManager.default.fileExists(atPath: candidate.path) {
        nextURL = candidate
      }
    }

    guard let targetURL = nextURL else {
      NSLog("[RNBridgeManager] ❌ 目标 Bundle 不可用，保持原状")
      return false
    }

    if previousURL == targetURL && bridge != nil {
      NSLog("[RNBridgeManager] ⏭ Bundle 未变化，无需切换")
      return false
    }

    RCTReloadCommandSetBundleURL(targetURL)
    bundleSource = source
    isBridgeReady = false
    isInitializing = true
    RCTTriggerReloadCommandListeners("RNBridgeManager.switchBundle")
    NSLog("[RNBridgeManager] ✅ 切换 Bundle 成功: \(source.rawValue) → \(targetURL.lastPathComponent)")
    return true
  }

  public func currentBundleDescription() -> String {
    let url = resolveActiveBundleURL()
    return """
    {
      "source": \(bundleSource.rawValue),
      "path": "\(url?.path ?? "nil")",
      "bridgeReady": \(isBridgeReady),
      "bridgeValid": \(bridge?.valid ?? false)
    }
    """
  }

  // MARK: - Bundle Resolution

  public func resolveActiveBundleURL() -> URL? {
    #if DEBUG
    if shouldUseRemoteDebug() {
      bundleSource = .remoteDebug
      return RCTBundleURLProvider.sharedSettings().jsBundleURL(forBundleRoot: "index")
    }
    #endif
    if let hot = hotUpdateBundleURL() {
      bundleSource = .hotUpdate
      return hot
    }
    bundleSource = .embedded
    return embeddedBundleURL()
  }

  public func hotUpdateBundleURL() -> URL? {
    if let path = HotUpdateBundleStore.currentBundlePath(),
       FileManager.default.fileExists(atPath: path) {
      return URL(fileURLWithPath: path)
    }
    return nil
  }

  public func embeddedBundleURL() -> URL? {
    let candidates = [
      Bundle.main.url(forResource: "main", withExtension: "jsbundle"),
      Bundle.main.url(forResource: "index", withExtension: "jsbundle"),
      Bundle(for: Self.self).url(forResource: "main", withExtension: "jsbundle"),
    ]
    return candidates.first { $0 != nil } ?? nil
  }

  // MARK: - Private

  private func shouldUseRemoteDebug() -> Bool {
    #if DEBUG
    return true
    #else
    return false
    #endif
  }

  private func flushPendingHandlersIfNeeded() {
    guard isBridgeReady, !pendingHandlers.isEmpty else { return }
    let handlers = pendingHandlers
    pendingHandlers.removeAll()
    isInitializing = false
    let currentBridge = bridge
    DispatchQueue.main.async {
      handlers.forEach { $0(currentBridge) }
    }
  }

  @objc private func handleJavaScriptDidLoad(_ note: Notification) {
    isBridgeReady = true
    isInitializing = false
    flushPendingHandlersIfNeeded()
  }
}
