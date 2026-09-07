import UIKit
import Flutter

enum PopSource: String {
    case nativeNavBarButton = "native_nav_bar"
    case nativeSwipe = "native_swipe"
    case androidBack = "android_back"
    case codeCall = "code_call"
    case flutterAppBar = "flutter_app_bar"
    case containerClose = "container_close"
    case unknown
}

final class ContainerDispatcher {
    static let shared = ContainerDispatcher()

    private let lock = NSLock()
    private var flutterRouteReadyHandlers: [String: (Result<Void, RouteError>) -> Void] = [:]
    private var currentFlutterRequestId: String?
    private var isFlutterContainerOnTop: Bool {
        lock.lock()
        defer { lock.unlock() }
        return currentFlutterRequestId != nil
    }

    private init() {}

    // MARK: - 分发入口

    func dispatch(
        request: RouteRequest,
        from presentingVC: UIViewController?,
        completion: @escaping RouteCompletion
    ) {
        switch request.container {
        case .native:
            dispatchNative(request: request, from: presentingVC, completion: completion)
        case .flutter:
            dispatchFlutter(request: request, from: presentingVC, completion: completion)
        }
    }

    // MARK: - Native 执行层

    private func dispatchNative(
        request: RouteRequest,
        from presentingVC: UIViewController?,
        completion: @escaping RouteCompletion
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let nav = presentingVC?.navigationController ?? Self.findRootNav() else {
                completion(.failure(.containerNotFound(routeName: request.routeName)))
                return
            }

            let targetVC = self.buildNativeViewController(request: request)
            self.applyAnimation(request: request, to: targetVC)

            switch request.presentMode {
            case .push:
                nav.pushViewController(targetVC, animated: request.animation != .none)
            case .present:
                let wrapper = UINavigationController(rootViewController: targetVC)
                wrapper.modalPresentationStyle = .fullScreen
                nav.present(wrapper, animated: request.animation != .none)
            case .replace:
                var vcs = nav.viewControllers
                if !vcs.isEmpty { vcs.removeLast() }
                vcs.append(targetVC)
                nav.setViewControllers(vcs, animated: request.animation != .none)
            }

            completion(.success(()))
        }
    }

    private func buildNativeViewController(request: RouteRequest) -> UIViewController {
        switch request.routeName {
        case "native_home":
            return ViewController()
        case "route_error":
            let vc = RouteErrorViewController()
            vc.configure(params: request.params, requestId: request.requestId)
            return vc
        default:
            let vc = NativePageViewController(route: request.routeName, params: request.params)
            return vc
        }
    }

    private func applyAnimation(request: RouteRequest, to vc: UIViewController) {
        switch request.animation {
        case .fade:
            let transition = CATransition()
            transition.type = .fade
            transition.duration = 0.25
            vc.navigationController?.view.layer.add(transition, forKey: kCATransition)
        case .slideUp:
            vc.modalTransitionStyle = .coverVertical
        default:
            break
        }
    }

    // MARK: - Flutter 执行层

    private func dispatchFlutter(
        request: RouteRequest,
        from presentingVC: UIViewController?,
        completion: @escaping RouteCompletion
    ) {
        FlutterEngineProvider.shared.startIfNeeded()
        guard FlutterEngineProvider.shared.isRunning else {
            completion(.failure(.engineNotReady(routeName: request.routeName)))
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let nav = presentingVC?.navigationController ?? Self.findRootNav() else {
                completion(.failure(.containerNotFound(routeName: request.routeName)))
                return
            }

            let engine = FlutterEngineProvider.shared.engine
            let navStyle = self.resolveNavStyle(request: request)
            let flutterVC = HybridFlutterViewController(engine: engine, navStyle: navStyle)
            flutterVC.currentRequestId = request.requestId
            flutterVC.routeName = request.routeName

            if navStyle == .native {
                flutterVC.title = request.params["__title"] as? String ?? request.routeName
            }

            self.lock.lock()
            self.flutterRouteReadyHandlers[request.requestId] = completion
            self.currentFlutterRequestId = request.requestId
            self.lock.unlock()

            let channelArgs: [String: Any] = [
                "version": request.version,
                "requestId": request.requestId,
                "routeName": request.routeName,
                "path": request.path,
                "params": request.params,
                "navStyle": navStyle.rawValue,
                "pageId": request.pageId,
                "animation": request.animation.rawValue,
                "presentMode": request.presentMode.rawValue,
                "isFirstEnter": !self.isFlutterContainerOnTop
            ]

            switch request.presentMode {
            case .push:
                if nav.topViewController is HybridFlutterViewController {
                    FlutterChannelRouterBridge.shared.notifyFlutterPush(arguments: channelArgs)
                } else {
                    FlutterChannelRouterBridge.shared.setPendingPushBeforeFlutterReady(
                        arguments: channelArgs,
                        for: request.requestId
                    )
                    nav.pushViewController(flutterVC, animated: request.animation != .none)
                }
            case .present:
                FlutterChannelRouterBridge.shared.setPendingPushBeforeFlutterReady(
                    arguments: channelArgs,
                    for: request.requestId
                )
                let navWrapper = UINavigationController(rootViewController: flutterVC)
                navWrapper.modalPresentationStyle = .fullScreen
                nav.present(navWrapper, animated: request.animation != .none)
            case .replace:
                FlutterChannelRouterBridge.shared.setPendingPushBeforeFlutterReady(
                    arguments: channelArgs,
                    for: request.requestId
                )
                var vcs = nav.viewControllers
                if !vcs.isEmpty, vcs.last is HybridFlutterViewController {
                    vcs.removeLast()
                }
                vcs.append(flutterVC)
                nav.setViewControllers(vcs, animated: request.animation != .none)
            }
        }
    }

    private func resolveNavStyle(request: RouteRequest) -> HybridNavStyle {
        if let raw = request.params["__navStyle"] as? String,
           let style = HybridNavStyle(rawValue: raw) {
            return style
        }
        switch request.animation {
        case .slideUp:
            return .flutter
        default:
            return .native
        }
    }

    // MARK: - Flutter → Host 回调

    func handleFlutterRouteReady(requestId: String, routeName: String) {
        lock.lock()
        let handler = flutterRouteReadyHandlers.removeValue(forKey: requestId)
        lock.unlock()

        DispatchQueue.main.async {
            handler?(.success(()))
        }
    }

    func handleFlutterRouteError(requestId: String, error: RouteError) {
        lock.lock()
        let handler = flutterRouteReadyHandlers.removeValue(forKey: requestId)
        lock.unlock()

        DispatchQueue.main.async {
            handler?(.failure(error))
        }
    }

    func handleFlutterContainerDismissed(requestId: String?) {
        lock.lock()
        if let reqId = requestId {
            flutterRouteReadyHandlers.removeValue(forKey: reqId)
        }
        if currentFlutterRequestId == requestId {
            currentFlutterRequestId = nil
        }
        lock.unlock()
    }

    static func findRootNav() -> UINavigationController? {
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        let window = windowScene?.windows.first(where: \.isKeyWindow) ?? UIApplication.shared.windows.first(where: \.isKeyWindow)

        var root = window?.rootViewController
        if let presented = root?.presentedViewController { root = presented }
        if let nav = root as? UINavigationController { return nav }
        if let tab = root as? UITabBarController {
            if let nav = tab.selectedViewController as? UINavigationController { return nav }
        }
        return root?.navigationController
    }
}

// MARK: - Flutter MethodChannel 桥（AppRouter ↔ Flutter 内部路由）

final class FlutterChannelRouterBridge {
    static let shared = FlutterChannelRouterBridge()

    private var channel: FlutterMethodChannel?
    private var pendingPush: [String: [String: Any]] = [:]
    private let lock = NSLock()

    private init() {}

    func attach(engine: FlutterEngine) {
        guard channel == nil else { return }
        let ch = FlutterMethodChannel(
            name: HybridChannelNames.routerV2,
            binaryMessenger: engine.binaryMessenger
        )
        ch.setMethodCallHandler { [weak self] call, result in
            self?.handleFlutterCall(call: call, result: result)
        }
        channel = ch
    }

    func notifyFlutterPush(arguments: [String: Any]) {
        lock.lock()
        defer { lock.unlock() }
        channel?.invokeMethod("showRouteV2", arguments: arguments)
    }

    func setPendingPushBeforeFlutterReady(arguments: [String: Any], for requestId: String) {
        lock.lock()
        pendingPush[requestId] = arguments
        lock.unlock()
    }

    func flushPendingPush(for requestId: String) {
        lock.lock()
        let args = pendingPush.removeValue(forKey: requestId)
        lock.unlock()
        if let args = args {
            notifyFlutterPush(arguments: args)
        }
    }

    func notifyFlutterSystemBack(source: String = PopSource.nativeNavBarButton.rawValue) {
        channel?.invokeMethod("systemBackV2", arguments: [
            "source": source,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ])
    }

    func notifyFlutterResetToBootstrap() {
        channel?.invokeMethod("resetToBootstrapV2", arguments: nil)
    }

    private func handleFlutterCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "flutterReadyV2":
            if let requestId = args["requestId"] as? String {
                flushPendingPush(for: requestId)
            }
            result(nil)

        case "routeReadyV2":
            let requestId = args["requestId"] as? String ?? ""
            let routeName = args["routeName"] as? String ?? ""
            ContainerDispatcher.shared.handleFlutterRouteReady(requestId: requestId, routeName: routeName)
            BackDispatcher.shared.handleFlutterCanPopUpdated(
                canPop: args["canPop"] as? Bool ?? false,
                routeName: routeName,
                requestId: requestId
            )
            result(nil)

        case "routeNotFoundV2":
            let requestId = args["requestId"] as? String ?? ""
            let routeName = args["routeName"] as? String ?? ""
            let path = args["path"] as? String ?? ""
            ContainerDispatcher.shared.handleFlutterRouteError(
                requestId: requestId,
                error: .flutterPageNotFound(routeName: routeName, path: path)
            )
            result(nil)

        case "openNativeV2":
            let routeName = args["routeName"] as? String ?? (args["route"] as? String ?? "native_page")
            let params = args["params"] as? [String: Any] ?? [:]
            DispatchQueue.main.async {
                AppRouter.shared.openInternal(
                    routeName: routeName,
                    params: params,
                    source: .inner,
                    sourcePage: routeName,
                    fromVC: ContainerDispatcher.findRootNav()?.topViewController,
                    onResult: nil
                )
            }
            result(nil)

        case "closeFlutterV2":
            let requestId = args["requestId"] as? String ?? ""
            let routeName = args["routeName"] as? String ?? ""
            let payload = args["result"]
            let isCancelled = args["cancelled"] as? Bool ?? false
            DispatchQueue.main.async {
                BackDispatcher.shared.handleFlutterInitiatedClose(
                    requestId: requestId,
                    routeName: routeName,
                    payload: payload,
                    isCancelled: isCancelled
                )
            }
            result(nil)

        case "canPopV2":
            let canPop = args["canPop"] as? Bool ?? false
            let routeName = args["routeName"] as? String ?? ""
            let requestId = args["requestId"] as? String ?? ""
            BackDispatcher.shared.handleFlutterCanPopUpdated(
                canPop: canPop,
                routeName: routeName,
                requestId: requestId
            )
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

// MARK: - Route Error Fallback VC

final class RouteErrorViewController: UIViewController {
    private var params: [String: Any] = [:]
    private var requestId: String = ""

    func configure(params: [String: Any], requestId: String) {
        self.params = params
        self.requestId = requestId
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "页面异常"
        view.backgroundColor = .systemBackground

        let icon = UIImageView(image: UIImage(systemName: "exclamationmark.triangle"))
        icon.tintColor = .systemOrange
        icon.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "抱歉，页面无法打开"
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textAlignment = .center

        let reason = params["failReason"] as? String ?? "未知错误"
        let code = params["failCode"] as? String ?? "-"
        let detailLabel = UILabel()
        detailLabel.numberOfLines = 0
        detailLabel.textAlignment = .center
        detailLabel.textColor = .secondaryLabel
        detailLabel.text = "错误码：\(code)\n原因：\(reason)\nrequestId：\(requestId)"

        let backButton = UIButton(type: .system)
        backButton.setTitle("返回上一页", for: .normal)
        backButton.addTarget(self, action: #selector(onBack), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [icon, titleLabel, detailLabel, backButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
    }

    @objc private func onBack() {
        navigationController?.popViewController(animated: true)
    }
}
