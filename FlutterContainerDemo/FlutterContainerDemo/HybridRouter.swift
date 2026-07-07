import UIKit
import Flutter

final class HybridRouter {
    static let shared = HybridRouter()

    private let channelName = HybridChannelNames.router
    private var channel: FlutterMethodChannel?

    private weak var navigationController: UINavigationController?
    private weak var pendingPresentingNavigationController: UINavigationController?
    private var pendingFlutterViewController: HybridFlutterViewController?
    private var pendingRouteRequest: (requestId: Int, route: String, params: [String: Any], navStyle: HybridNavStyle)?
    private var pendingResult: ((Any?) -> Void)?

    private var currentNavStyle: HybridNavStyle = .native
    private var nextRouteRequestID: Int = 0

    private init() {}

    func attach(engine: FlutterEngine) {
        guard channel == nil else { return }

        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: engine.binaryMessenger)
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else {
                result(FlutterError(code: "router_released", message: nil, details: nil))
                return
            }

            switch call.method {
            case "openNative":
                self.handleOpenNative(call: call, result: result)
            case "closeFlutter":
                self.handleCloseFlutter(call: call, result: result)
            case "flutterReady":
                result(nil)
            case "routeReady":
                self.handleRouteReady(call: call, result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        self.channel = channel
    }

    func showFlutter(from viewController: UIViewController, route: String, params: [String: Any], navStyle: HybridNavStyle = .native, onResult: ((Any?) -> Void)? = nil) {
        let engine = FlutterEngineProvider.shared.engine

        let flutterViewController = HybridFlutterViewController(engine: engine, navStyle: navStyle)

        if navStyle == .native {
            flutterViewController.title = route
        }

        let requestId = nextRouteRequestID
        nextRouteRequestID += 1

        currentNavStyle = navStyle
        pendingResult = onResult
        navigationController = viewController.navigationController
        pendingPresentingNavigationController = viewController.navigationController
        pendingFlutterViewController = flutterViewController
        pendingRouteRequest = (requestId, route, params, navStyle)

        DispatchQueue.main.async { [weak self] in
            self?.showRoute(requestId: requestId, route: route, params: params, navStyle: navStyle)
        }
    }

    private func showRoute(requestId: Int, route: String, params: [String: Any], navStyle: HybridNavStyle) {
        channel?.invokeMethod("showRoute", arguments: [
            "version": 1,
            "requestId": requestId,
            "route": route,
            "params": params,
            "navStyle": navStyle.rawValue
        ])
    }

    private func handleRouteReady(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        let route = args?["route"] as? String
        let requestId = args?["requestId"] as? Int

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let pendingRequest = self.pendingRouteRequest,
                  pendingRequest.route == route,
                  pendingRequest.requestId == requestId,
                  let flutterViewController = self.pendingFlutterViewController,
                  let navigationController = self.pendingPresentingNavigationController else {
                result(nil)
                return
            }

            if navigationController.topViewController !== flutterViewController {
                navigationController.pushViewController(flutterViewController, animated: true)
            }

            self.pendingFlutterViewController = nil
            self.pendingPresentingNavigationController = nil
            self.pendingRouteRequest = nil
            result(nil)
        }
    }

    func handleFlutterViewControllerDismissed() {
        pendingFlutterViewController = nil
        pendingPresentingNavigationController = nil
        pendingRouteRequest = nil
        pendingResult = nil
        currentNavStyle = .native
        resetToBootstrap()
    }

    private func resetToBootstrap() {
        channel?.invokeMethod("resetToBootstrap", arguments: [
            "version": 1
        ])
    }

    private func handleOpenNative(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "bad_args", message: "arguments must be a map", details: nil))
            return
        }

        let route = args["route"] as? String ?? "native"
        let params = args["params"] as? [String: Any] ?? [:]

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let vc = NativePageViewController(route: route, params: params)
            self.navigationController?.pushViewController(vc, animated: true)
        }

        result(nil)
    }

    private func handleCloseFlutter(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        let payload = args?["result"]

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            if self.currentNavStyle != .native {
                self.navigationController?.setNavigationBarHidden(false, animated: true)
            }

            self.navigationController?.popViewController(animated: true)
            self.pendingResult?(payload)
            self.pendingResult = nil
            self.currentNavStyle = .native
        }

        result(nil)
    }
}

enum HybridChannelNames {
    static let router = "com.example.hybrid/router"
    static let method = "com.maocf.hybrid/method"
    static let event = "com.maocf.hybrid/event"
    static let messageString = "com.maocf.hybrid/message_string"
    static let messageStandard = "com.maocf.hybrid/message_standard"
}

final class HybridChannelBridge {
    static let shared = HybridChannelBridge()

    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var stringMessageChannel: FlutterBasicMessageChannel?
    private var standardMessageChannel: FlutterBasicMessageChannel?
    private let eventStreamHandler = HybridEventStreamHandler()

    private init() {}

    func attach(engine: FlutterEngine) {
        guard methodChannel == nil else { return }

        let messenger = engine.binaryMessenger

        let methodChannel = FlutterMethodChannel(name: HybridChannelNames.method, binaryMessenger: messenger)
        methodChannel.setMethodCallHandler(handleMethodCall)
        self.methodChannel = methodChannel

        let eventChannel = FlutterEventChannel(name: HybridChannelNames.event, binaryMessenger: messenger)
        eventChannel.setStreamHandler(eventStreamHandler)
        self.eventChannel = eventChannel

        let stringChannel = FlutterBasicMessageChannel(
            name: HybridChannelNames.messageString,
            binaryMessenger: messenger,
            codec: FlutterStringCodec.sharedInstance()
        )
        stringChannel.setMessageHandler { message, reply in
            let text = (message as? String) ?? ""
            reply("iOS string echo: \(text)")
        }
        stringMessageChannel = stringChannel

        let standardChannel = FlutterBasicMessageChannel(
            name: HybridChannelNames.messageStandard,
            binaryMessenger: messenger,
            codec: FlutterStandardMessageCodec.sharedInstance()
        )
        standardChannel.setMessageHandler { message, reply in
            let payload = message as? [String: Any] ?? [:]
            let requestId = payload["requestId"] as? String ?? UUID().uuidString
            reply([
                "code": 0,
                "message": "standard message success",
                "requestId": requestId,
                "data": [
                    "platform": "iOS",
                    "echo": payload,
                    "receivedAt": ISO8601DateFormatter().string(from: Date())
                ]
            ])
        }
        standardMessageChannel = standardChannel
    }

    private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        let requestId = args["requestId"] as? String ?? UUID().uuidString

        switch call.method {
        case "getDeviceInfo":
            let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
            let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
            result(makeResponse(
                requestId: requestId,
                data: [
                    "deviceName": UIDevice.current.name,
                    "systemName": UIDevice.current.systemName,
                    "systemVersion": UIDevice.current.systemVersion,
                    "appVersion": appVersion,
                    "buildNumber": buildNumber
                ]
            ))
        case "getScreenMetrics":
            DispatchQueue.main.async {
                result(self.makeResponse(
                    requestId: requestId,
                    message: "screen metrics success",
                    data: self.buildScreenMetrics()
                ))
            }
        case "pickPhotoMock":
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                result(self.makeResponse(
                    requestId: requestId,
                    message: "mock photo selected",
                    data: [
                        "assetId": "mock_asset_001",
                        "fileName": "sample_photo.jpg",
                        "width": 1280,
                        "height": 720,
                        "source": "mock_album"
                    ]
                ))
            }
        case "getLocationMock":
            result(makeResponse(
                requestId: requestId,
                message: "mock location success",
                data: [
                    "latitude": 31.2304,
                    "longitude": 121.4737,
                    "city": "Shanghai",
                    "accuracy": 15
                ]
            ))
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func makeResponse(
        requestId: String,
        message: String = "success",
        data: [String: Any],
        code: Int = 0
    ) -> [String: Any] {
        [
            "code": code,
            "message": message,
            "data": data,
            "requestId": requestId
        ]
    }

    private func buildScreenMetrics() -> [String: Any] {
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        let window = windowScene?.windows.first(where: \.isKeyWindow) ?? UIApplication.shared.windows.first(where: \.isKeyWindow)
        let rootViewController = window?.rootViewController
        let topViewController = topViewController(from: rootViewController)
        let navigationController = topViewController?.navigationController ?? rootViewController as? UINavigationController
        let tabBarController = topViewController?.tabBarController

        let screenBounds = UIScreen.main.bounds
        let screenScale = UIScreen.main.scale
        let statusBarHeight = windowScene?.statusBarManager?.statusBarFrame.height ?? window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
        let navigationBarHeight = navigationController?.navigationBar.frame.height ?? 0
        let tabBarHeight = tabBarController?.tabBar.frame.height ?? 0
        let safeAreaInsets = window?.safeAreaInsets ?? .zero

        return [
            "screenWidth": screenBounds.width,
            "screenHeight": screenBounds.height,
            "screenScale": screenScale,
            "statusBarHeight": statusBarHeight,
            "navigationBarHeight": navigationBarHeight,
            "navigationTotalHeight": statusBarHeight + navigationBarHeight,
            "tabBarHeight": tabBarHeight,
            "topSafeArea": safeAreaInsets.top,
            "bottomSafeArea": safeAreaInsets.bottom,
            "leftSafeArea": safeAreaInsets.left,
            "rightSafeArea": safeAreaInsets.right,
            "windowWidth": window?.bounds.width ?? screenBounds.width,
            "windowHeight": window?.bounds.height ?? screenBounds.height,
            "orientation": screenBounds.width > screenBounds.height ? "landscape" : "portrait"
        ]
    }

    private func topViewController(from rootViewController: UIViewController?) -> UIViewController? {
        if let navigationController = rootViewController as? UINavigationController {
            return topViewController(from: navigationController.visibleViewController)
        }
        if let tabBarController = rootViewController as? UITabBarController {
            return topViewController(from: tabBarController.selectedViewController)
        }
        if let presentedViewController = rootViewController?.presentedViewController {
            return topViewController(from: presentedViewController)
        }
        return rootViewController
    }
}

final class HybridEventStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private var timer: Timer?
    private var tick: Int = 0
    private var currentEventName: String = "sensorMock"

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        tick = 0

        let args = arguments as? [String: Any]
        currentEventName = args?["eventName"] as? String ?? "sensorMock"

        emitEvent(named: currentEventName)
        startTimer(for: currentEventName)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        stopTimer()
        eventSink = nil
        return nil
    }

    private func startTimer(for eventName: String) {
        stopTimer()

        let interval: TimeInterval = eventName == "notificationMock" ? 2.0 : 1.0
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.emitEvent(named: eventName)
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func emitEvent(named eventName: String) {
        guard let eventSink else { return }
        tick += 1

        let payload: [String: Any]
        switch eventName {
        case "notificationMock":
            payload = [
                "id": "notice_\(tick)",
                "title": "Mock Notification #\(tick)",
                "body": "This is a simulated push notification from iOS.",
                "badge": tick
            ]
        default:
            payload = [
                "sequence": tick,
                "x": Double(tick) * 0.11,
                "y": Double(tick) * 0.22,
                "z": Double(tick) * 0.33
            ]
        }

        eventSink([
            "eventName": eventName,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "payload": payload
        ])
    }
}
