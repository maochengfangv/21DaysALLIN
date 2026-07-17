import UIKit
import React
import React_RCTAppDelegate
import ReactAppDependencyProvider

final class ReactNativeHost {
  static let shared = ReactNativeHost()

  private var reactNativeDelegate: ContainerReactNativeDelegate?
  private var reactNativeFactory: RCTReactNativeFactory?
  private var cachedLaunchOptions: [UIApplication.LaunchOptionsKey: Any]?

  private init() {}

  func bootstrap(with launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) {
    if let launchOptions {
      cachedLaunchOptions = launchOptions
    }

    guard reactNativeFactory == nil else {
      return
    }

    let delegate = ContainerReactNativeDelegate()
    delegate.dependencyProvider = RCTAppDependencyProvider()

    reactNativeDelegate = delegate
    reactNativeFactory = RCTReactNativeFactory(delegate: delegate)
  }

  func makeRootView(
    moduleName: String,
    initialProperties: [String: Any]? = nil
  ) -> UIView {
    bootstrap()

    guard let rootViewFactory = reactNativeFactory?.rootViewFactory else {
      fatalError("React Native factory has not been initialized.")
    }

    return rootViewFactory.view(
      withModuleName: moduleName,
      initialProperties: initialProperties,
      launchOptions: cachedLaunchOptions
    )
  }

  var bridge: RCTBridge? {
    if let bridge = reactNativeFactory?.bridge {
      return bridge
    }
    return reactNativeFactory?.rootViewFactory.bridge
  }
}

final class ContainerReactNativeDelegate: RCTDefaultReactNativeFactoryDelegate {
  override func sourceURL(for bridge: RCTBridge) -> URL? {
    bundleURL()
  }

  override func bundleURL() -> URL? {
#if DEBUG
    // 从 Info.plist 读取自定义 Metro 服务器 IP（如 "192.168.1.100:8081"）
    if let customIP = Bundle.main.object(forInfoDictionaryKey: "RNMetroServerIP") as? String,
       !customIP.isEmpty {
      let urlString = "http://\(customIP)/index.bundle?platform=ios&dev=true&minify=false"
      if let url = URL(string: urlString) {
        return url
      }
    }
    // 未配置 IP 时自动检测（localhost:8081）
    return RCTBundleURLProvider.sharedSettings().jsBundleURL(forBundleRoot: "index")
#else
    Bundle.main.url(forResource: "main", withExtension: "jsbundle")
#endif
  }
}
