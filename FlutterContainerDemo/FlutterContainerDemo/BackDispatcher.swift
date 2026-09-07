import UIKit
import Flutter

final class BackDispatcher {
    static let shared = BackDispatcher()

    private let lock = NSLock()
    private var flutterCanPop: Bool = false
    private var flutterCurrentRouteName: String = ""
    private var flutterCurrentRequestId: String = ""
    private var popInFlight: Bool = false
    private var pendingPopToken: Int = 0

    private init() {}

    // MARK: - Flutter CanPop 状态同步

    func handleFlutterCanPopUpdated(canPop: Bool, routeName: String, requestId: String) {
        lock.lock()
        defer { lock.unlock() }
        flutterCanPop = canPop
        flutterCurrentRouteName = routeName
        flutterCurrentRequestId = requestId
    }

    // MARK: - 宿主捕获返回事件入口

    @discardableResult
    func handleBackPress(
        source: PopSource,
        from flutterVC: HybridFlutterViewController? = nil
    ) -> Bool {
        lock.lock()
        if popInFlight {
            lock.unlock()
            return false
        }
        popInFlight = true
        pendingPopToken += 1
        let token = pendingPopToken
        lock.unlock()

        let hasFlutterVCOnTop = self.hasFlutterContainerOnTop()

        if hasFlutterVCOnTop && flutterCanPop {
            consumeFlutterBack(token: token, source: source)
            return true
        }

        if hasFlutterVCOnTop {
            popFlutterContainerAndResolveResult(token: token, source: source)
            return true
        }

        let consumed = fallthroughToNativePop(token: token, source: source)
        return consumed
    }

    // MARK: - Flutter 主动发起 closeFlutterV2

    func handleFlutterInitiatedClose(
        requestId: String,
        routeName: String,
        payload: Any?,
        isCancelled: Bool
    ) {
        lock.lock()
        let nav = ContainerDispatcher.findRootNav()
        let topIsFlutter = nav?.topViewController is HybridFlutterViewController
        lock.unlock()

        resolvePendingRequests(
            requestId: requestId,
            routeName: routeName,
            payload: payload,
            isCancelled: isCancelled
        )

        guard topIsFlutter else {
            resetPopFlagAsync()
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let nav = ContainerDispatcher.findRootNav() {
                let fromRoute = routeName
                let toRoute = Self.nativeTopRouteName(nav: nav)
                nav.popViewController(animated: true)

                RouteLogger.shared.logPop(
                    fromRoute: fromRoute,
                    toRoute: toRoute,
                    container: RouteContainer.flutter.rawValue,
                    requestId: requestId,
                    success: true,
                    reason: "flutter_initiated_close"
                )

                self.afterHostPopCleanup()
            } else {
                    self.resetPopFlagAsync()
                }
            }
    }

    // MARK: - Private

    private func consumeFlutterBack(token: Int, source: PopSource) {
        DispatchQueue.main.async { [weak self] in
            FlutterChannelRouterBridge.shared.notifyFlutterSystemBack(source: source.rawValue)

            RouteLogger.shared.logPop(
                fromRoute: self?.flutterCurrentRouteName ?? "",
                toRoute: "(flutter_inner)",
                container: RouteContainer.flutter.rawValue,
                requestId: self?.flutterCurrentRequestId ?? "",
                success: true,
                reason: "flutter_inner_consume_\(source.rawValue)"
            )
            self?.resetPopFlagAsync(token: token)
        }
    }

    private func popFlutterContainerAndResolveResult(token: Int, source: PopSource) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let nav = ContainerDispatcher.findRootNav() else {
                self.resetPopFlagAsync(token: token)
                return
            }

            let topVC = nav.topViewController
            let flutterRequestId = self.flutterCurrentRequestId
            let flutterRoute = self.flutterCurrentRouteName

            if topVC is HybridFlutterViewController {
                let fromRoute = flutterRoute
                let toRoute = Self.nativeTopRouteName(nav: nav, skipLast: 1)

                let isMovingFromParent = {
                    nav.popViewController(animated: true) != nil
                }

                let success = isMovingFromParent()

                if success {
                    self.resolvePendingRequests(
                        requestId: flutterRequestId,
                        routeName: flutterRoute,
                        payload: nil,
                        isCancelled: true
                    )

                    RouteLogger.shared.logPop(
                        fromRoute: fromRoute,
                        toRoute: toRoute,
                        container: RouteContainer.flutter.rawValue,
                        requestId: flutterRequestId,
                        success: true,
                        reason: "host_pop_flutter_container_\(source.rawValue)"
                    )

                    self.afterHostPopCleanup()
                } else {
                    RouteLogger.shared.logPop(
                        fromRoute: fromRoute,
                        toRoute: toRoute,
                        container: RouteContainer.flutter.rawValue,
                        requestId: flutterRequestId,
                        success: false,
                        reason: "pop_failed_no_vc"
                    )
                }
            } else {
                ContainerDispatcher.shared.handleFlutterContainerDismissed(requestId: flutterRequestId)
            }

            self.resetPopFlagAsync(token: token)
        }
    }

    private func fallthroughToNativePop(token: Int, source: PopSource) -> Bool {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let nav = ContainerDispatcher.findRootNav() else {
                self.resetPopFlagAsync(token: token)
                return
            }
            let fromRoute = Self.nativeTopRouteName(nav: nav)
            let toRoute = Self.nativeTopRouteName(nav: nav, skipLast: 1)
            let requestId = UUID().uuidString

            if nav.viewControllers.count > 1 {
                nav.popViewController(animated: true)
                RouteLogger.shared.logPop(
                    fromRoute: fromRoute,
                    toRoute: toRoute,
                    container: RouteContainer.native.rawValue,
                    requestId: requestId,
                    success: true,
                    reason: "native_pop_\(source.rawValue)"
                )
            } else if let root = nav.presentingViewController {
                root.dismiss(animated: true)
                RouteLogger.shared.logPop(
                    fromRoute: fromRoute,
                    toRoute: "(dismiss)",
                    container: RouteContainer.native.rawValue,
                    requestId: requestId,
                    success: true,
                    reason: "native_dismiss_\(source.rawValue)"
                )
            } else {
                RouteLogger.shared.logPop(
                    fromRoute: fromRoute,
                    toRoute: "(root)",
                    container: RouteContainer.native.rawValue,
                    requestId: requestId,
                    success: false,
                    reason: "pop_stack_corrupted_at_root"
                )
            }
            self.resetPopFlagAsync(token: token)
        }
        return true
    }

    private func afterHostPopCleanup() {
        FlutterChannelRouterBridge.shared.notifyFlutterResetToBootstrap()
        ContainerDispatcher.shared.handleFlutterContainerDismissed(requestId: flutterCurrentRequestId)
        lock.lock()
        flutterCanPop = false
        flutterCurrentRouteName = ""
        flutterCurrentRequestId = ""
        lock.unlock()
        resetPopFlagAsync()
    }

    private func resolvePendingRequests(
        requestId: String,
        routeName: String,
        payload: Any?,
        isCancelled: Bool
    ) {
        let size: Int = {
            if let dict = payload as? [String: Any] {
                return dict.count
            } else if let str = payload as? String {
                return str.utf8.count
            } else if payload != nil {
                return 1
            }
            return 0
        }()

        RouteLogger.shared.logResult(
            requestId: requestId,
            routeName: routeName,
            payloadSize: size,
            cancelled: isCancelled
        )

        let result = RouteResult(
            requestId: requestId,
            pageId: "",
            routeName: routeName,
            payload: payload,
            isCancelled: isCancelled
        )
        PendingRequestStore.shared.resolveResult(result)
    }

    private func hasFlutterContainerOnTop() -> Bool {
        guard let nav = ContainerDispatcher.findRootNav() else { return false }
        return nav.topViewController is HybridFlutterViewController
    }

    private static func nativeTopRouteName(nav: UINavigationController, skipLast: Int = 0) -> String {
        let count = nav.viewControllers.count
        guard count - skipLast - 1 >= 0 else { return "root" }
        let vc = nav.viewControllers[count - skipLast - 1]
        if vc is HybridFlutterViewController {
            return "flutter_container"
        }
        if vc is ViewController {
            return "native_home"
        }
        if vc is NativePageViewController {
            return "native_page"
        }
        if vc is RouteErrorViewController {
            return "route_error"
        }
        return String(describing: type(of: vc))
    }

    private func resetPopFlagAsync(token: Int? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lock.lock()
            defer { self.lock.unlock() }
            if let t = token, t != self.pendingPopToken { return }
            self.popInFlight = false
        }
    }
}
