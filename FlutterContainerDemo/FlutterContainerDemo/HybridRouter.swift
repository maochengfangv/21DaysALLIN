import UIKit
import Flutter

final class HybridRouter {
    static let shared = HybridRouter()

    private let channelName = "com.example.hybrid/router"
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
