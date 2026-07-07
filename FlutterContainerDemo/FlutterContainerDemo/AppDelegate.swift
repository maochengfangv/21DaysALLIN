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

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

}

final class FlutterEngineProvider {
    static let shared = FlutterEngineProvider()

    let engine: FlutterEngine
    private var isRunning = false

    private init() {
        engine = FlutterEngine(name: "main_flutter_engine")
    }

    func startIfNeeded() {
        guard !isRunning else { return }
        engine.run()
        GeneratedPluginRegistrant.register(with: engine)
        NativePlatformViewRegistrar.register(with: engine)
        HybridRouter.shared.attach(engine: engine)
        HybridChannelBridge.shared.attach(engine: engine)
        isRunning = true
    }
}
