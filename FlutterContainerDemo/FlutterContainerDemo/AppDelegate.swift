//
//  AppDelegate.swift
//  FlutterContainerDemo
//
//  Created by maochengfang on 2026/7/1.
//

import UIKit
import Flutter
import FlutterPluginRegistrant

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FlutterEngineProvider.shared.startIfNeeded()
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }
}

final class FlutterEngineProvider {
    static let shared = FlutterEngineProvider()

    let engine: FlutterEngine
    private(set) var isRunning: Bool = false
    private let lock = NSLock()

    private init() {
        engine = FlutterEngine(name: "main_flutter_engine")
    }

    func startIfNeeded() {
        lock.lock()
        guard !isRunning else {
            lock.unlock()
            return
        }
        defer { lock.unlock() }

        let startedAt = Date()
        engine.run()
        GeneratedPluginRegistrant.register(with: engine)
        NativePlatformViewRegistrar.register(with: engine)

        HybridRouter.shared.attach(engine: engine)
        HybridChannelBridge.shared.attach(engine: engine)
        FlutterChannelRouterBridge.shared.attach(engine: engine)

        isRunning = true

        let cost = Int64(Date().timeIntervalSince(startedAt) * 1000)
        #if DEBUG
        print("[RouteAnalytics] event=route_engine_warmup cost=\(cost)ms")
        #endif
    }
}
