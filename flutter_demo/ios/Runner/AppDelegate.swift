import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var isolateDemoChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "IsolateMethodChannelDemo"
    ) else {
      assertionFailure("Failed to create registrar for IsolateMethodChannelDemo")
      return
    }

    let channel = FlutterMethodChannel(
      name: "demo/isolate_method_channel",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "nativeEcho":
        let arguments = call.arguments as? [String: Any]
        let message = arguments?["message"] as? String ?? "empty"
        result([
          "from": "iOS Native",
          "echo": "Native 收到: \(message)",
          "thread": Thread.isMainThread ? "main-thread" : "background-thread",
          "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    isolateDemoChannel = channel
  }
}
