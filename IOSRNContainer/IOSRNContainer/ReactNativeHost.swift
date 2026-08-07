import UIKit
import React
import React_RCTAppDelegate
import ReactAppDependencyProvider
#if canImport(RNBridgePodspec)
import RNBridgePodspec
#endif

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

        #if canImport(RNBridgePodspec)
        RNBridgeManager.shared.preloadPolicy = .onAppDidFinishLaunching
        RNBridgeManager.shared.preloadIfNeeded(launchOptions: launchOptions)
        #endif

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
        #if canImport(RNBridgePodspec)
        if RNBridgeManager.shared.isBridgeReady, let bridge = RNBridgeManager.shared.bridge {
            let rootView = RCTRootView(
                bridge: bridge,
                moduleName: moduleName,
                initialProperties: initialProperties
            )
            rootView.backgroundColor = UIColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1)
            return rootView
        }
        #endif

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
        #if canImport(RNBridgePodspec)
        if let bridge = RNBridgeManager.shared.bridge {
            return bridge
        }
        #endif
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
        if let customIP = Bundle.main.object(forInfoDictionaryKey: "RNMetroServerIP") as? String,
           !customIP.isEmpty {
            let urlString = "http://\(customIP)/index.bundle?platform=ios&dev=true&minify=false"
            if let url = URL(string: urlString) {
                return url
            }
        }
        return RCTBundleURLProvider.sharedSettings().jsBundleURL(forBundleRoot: "index")
        #else
        #if canImport(RNBridgePodspec)
        if let hotURL = RNBridgeManager.shared.hotUpdateBundleURL() {
            return hotURL
        }
        #endif
        return Bundle.main.url(forResource: "main", withExtension: "jsbundle")
        #endif
    }
}
