import UIKit
import Flutter

final class AppRouter {
    static let shared = AppRouter()

    private let lock = NSLock()
    private var loginResumeRequest: RouteRequest?

    private init() {}

    // MARK: - 对外统一入口

    @discardableResult
    func open(
        routeName: String,
        params: [String: Any] = [:],
        source: RouteSource = .inner,
        sourcePage: String = "unknown",
        from presentingVC: UIViewController? = nil,
        onResult: RouteResultCallback? = nil
    ) -> String? {
        var request = RouteRequest(
            routeName: routeName,
            path: "/\(routeName)",
            params: params,
            source: source,
            sourcePage: sourcePage
        )
        return executeOpen(request: &request, from: presentingVC, onResult: onResult)?.requestId
    }

    @discardableResult
    func open(
        deeplink url: URL,
        source: RouteSource = .deeplink,
        from presentingVC: UIViewController? = nil,
        onResult: RouteResultCallback? = nil
    ) -> String? {
        guard var request = RouteRegistry.shared.parseDeeplink(url, source: source) else {
            let fallback = RouteRequest(
                routeName: "route_error",
                path: "/error/route",
                params: [
                    "failReason": "deeplink parse failed: \(url.absoluteString)",
                    "failCode": "E_DEEPLINK_PARSE"
                ],
                source: source,
                sourcePage: source.rawValue
            )
            var mutable = fallback
            return executeOpen(request: &mutable, from: presentingVC, onResult: onResult)?.requestId
        }
        return executeOpen(request: &request, from: presentingVC, onResult: onResult)?.requestId
    }

    // MARK: - 内部调用入口（Flutter → Native）

    func openInternal(
        routeName: String,
        params: [String: Any],
        source: RouteSource,
        sourcePage: String,
        fromVC: UIViewController?,
        onResult: RouteResultCallback?
    ) -> String? {
        var request = RouteRequest(
            routeName: routeName,
            path: "/\(routeName)",
            params: params,
            source: source,
            sourcePage: sourcePage
        )
        return executeOpen(request: &request, from: fromVC, onResult: onResult)?.requestId
    }

    // MARK: - PushForResult 语义化封装

    @discardableResult
    func pushForResult(
        routeName: String,
        params: [String: Any] = [:],
        sourcePage: String = "unknown",
        from presentingVC: UIViewController? = nil,
        onResult: @escaping RouteResultCallback
    ) -> String? {
        open(
            routeName: routeName,
            params: params,
            source: .inner,
            sourcePage: sourcePage,
            from: presentingVC,
            onResult: onResult
        )
    }

    func popWithResult(
        presentingVC: UIViewController? = nil,
        payload: Any? = nil,
        isCancelled: Bool = false
    ) {
        guard let nav = presentingVC?.navigationController ?? ContainerDispatcher.findRootNav() else { return }
        let topVC = nav.topViewController

        if let flutterVC = topVC as? HybridFlutterViewController {
            let requestId = flutterVC.currentRequestId ?? ""
            BackDispatcher.shared.handleFlutterInitiatedClose(
                requestId: requestId,
                routeName: flutterVC.routeName ?? "",
                payload: payload,
                isCancelled: isCancelled
            )
            return
        }

        if nav.viewControllers.count > 1 {
            let fromVC = nav.viewControllers.last
            let fromRoute = String(describing: type(of: fromVC ?? UIViewController()))
            nav.popViewController(animated: true)
            RouteLogger.shared.logPop(
                fromRoute: fromRoute,
                toRoute: String(describing: type(of: nav.topViewController ?? UIViewController())),
                container: RouteContainer.native.rawValue,
                requestId: UUID().uuidString,
                success: true,
                reason: "code_call_popWithResult"
            )
        }
    }

    // MARK: - 核心执行链

    private func executeOpen(
        request: inout RouteRequest,
        from presentingVC: UIViewController?,
        onResult: RouteResultCallback?
    ) -> RouteRequest? {
        RouteLogger.shared.beginOpen(request: request)

        if PendingRequestStore.shared.isDuplicateOpen(routeName: request.routeName) {
            let err = RouteError.duplicateRequest(requestId: request.requestId)
            RouteLogger.shared.endOpenFail(request: request, error: err, extra: ["dedup": "window_0.5s"])
            handleRouteFailure(request: request, error: err, from: presentingVC)
            return nil
        }

        guard let meta = RouteRegistry.shared.resolveMeta(from: &request) else {
            let err = RouteError.routeNotFound(routeName: request.routeName)
            RouteLogger.shared.endOpenFail(request: request, error: err)
            handleRouteFailure(request: request, error: err, from: presentingVC)
            return nil
        }

        switch RouteRegistry.shared.validate(request: request) {
        case .failure(let err):
            RouteLogger.shared.endOpenFail(request: request, error: err)
            if case .notLogin = err {
                handleLoginRequired(request: request, from: presentingVC, onResult: onResult)
                return nil
            }
            handleRouteFailure(request: request, error: err, from: presentingVC)
            return nil
        case .success:
            break
        }

        if request.container == .flutter && !FlutterEngineProvider.shared.isRunning {
            FlutterEngineProvider.shared.startIfNeeded()
            RouteLogger.shared.logFallback(
                requestId: request.requestId,
                originalRoute: request.routeName,
                fallbackRoute: "(engine warmup)",
                error: .engineNotReady(routeName: request.routeName)
            )
            if !FlutterEngineProvider.shared.isRunning {
                let err = RouteError.engineNotReady(routeName: request.routeName)
                RouteLogger.shared.endOpenFail(request: request, error: err)
                handleRouteFailure(request: request, error: err, from: presentingVC)
                return nil
            }
        }

        PendingRequestStore.shared.store(request: request, callback: onResult)

        var capturedRequest = request
        ContainerDispatcher.shared.dispatch(
            request: request,
            from: presentingVC
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                RouteLogger.shared.endOpenSuccess(
                    request: capturedRequest,
                    extra: ["container": meta.container.rawValue]
                )
            case .failure(let err):
                RouteLogger.shared.endOpenFail(request: capturedRequest, error: err)
                PendingRequestStore.shared.removeRequest(requestId: capturedRequest.requestId)
                self.handleRouteFailure(request: capturedRequest, error: err, from: presentingVC)
            }
        }

        return request
    }

    // MARK: - 异常治理

    private func handleRouteFailure(
        request: RouteRequest,
        error: RouteError,
        from presentingVC: UIViewController?
    ) {
        RouteLogger.shared.logFallback(
            requestId: request.requestId,
            originalRoute: request.routeName,
            fallbackRoute: "route_error",
            error: error
        )

        var fallback = RouteRequest(
            routeName: "route_error",
            path: "/error/route",
            params: [
                "failReason": error.description,
                "failCode": error.errorCode,
                "originalRoute": request.routeName,
                "originalParams": request.params
            ],
            source: request.source,
            sourcePage: request.sourcePage
        )
        fallback.requestId = request.requestId

        if let meta = RouteRegistry.shared.meta(for: "route_error") {
            fallback.container = meta.container
        }

        if let resultCallback = PendingRequestStore.shared.request(for: request.requestId) {
            let cancelled = RouteResult(
                requestId: request.requestId,
                pageId: "",
                routeName: request.routeName,
                payload: nil,
                isCancelled: true
            )
            PendingRequestStore.shared.resolveResult(cancelled)
        }

        ContainerDispatcher.shared.dispatch(
            request: fallback,
            from: presentingVC
        ) { _ in }
    }

    private func handleLoginRequired(
        request: RouteRequest,
        from presentingVC: UIViewController?,
        onResult: RouteResultCallback?
    ) {
        lock.lock()
        loginResumeRequest = request
        lock.unlock()

        var loginReq = RouteRequest(
            routeName: "login",
            path: "/login",
            params: ["redirectRoute": request.routeName, "redirectParams": request.params],
            source: request.source,
            sourcePage: request.sourcePage
        )
        if let meta = RouteRegistry.shared.meta(for: "login") {
            loginReq.container = meta.container
            loginReq.presentMode = meta.presentMode
        }

        RouteLogger.shared.beginOpen(request: loginReq)
        PendingRequestStore.shared.store(request: loginReq) { [weak self] loginResult in
            guard let self else { return }
            if loginResult.isCancelled {
                let cancelled = RouteResult(
                    requestId: request.requestId,
                    pageId: "",
                    routeName: request.routeName,
                    payload: nil,
                    isCancelled: true
                )
                PendingRequestStore.shared.resolveResult(cancelled)
                return
            }
            if UserSession.shared.isLoggedIn {
                var resume = request
                let _ = self.executeOpen(request: &resume, from: presentingVC, onResult: onResult)
            }
        }

        ContainerDispatcher.shared.dispatch(request: loginReq, from: presentingVC) { result in
            switch result {
            case .success:
                RouteLogger.shared.endOpenSuccess(request: loginReq, extra: ["reason": "login_redirect_from_\(request.routeName)"])
            case .failure(let err):
                RouteLogger.shared.endOpenFail(request: loginReq, error: err)
            }
        }
    }
}
