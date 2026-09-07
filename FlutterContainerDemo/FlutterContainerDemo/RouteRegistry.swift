import Foundation
import UIKit

final class RouteRegistry {
    static let shared = RouteRegistry()

    private var routeMetaMap: [String: RouteMeta] = [:]
    private var pathToRouteName: [String: String] = [:]
    private let lock = NSLock()

    private init() {
        registerDefaultRoutes()
    }

    func register(meta: RouteMeta) {
        lock.lock()
        defer { lock.unlock() }
        routeMetaMap[meta.routeName] = meta
        pathToRouteName[meta.path] = meta.routeName
    }

    func meta(for routeName: String) -> RouteMeta? {
        lock.lock()
        defer { lock.unlock() }
        return routeMetaMap[routeName]
    }

    func routeName(forPath path: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return pathToRouteName[path]
    }

    func allRouteNames() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(routeMetaMap.keys)
    }

    func validate(request: RouteRequest) -> Result<Void, RouteError> {
        guard let meta = meta(for: request.routeName) else {
            if let resolvedName = routeName(forPath: request.path) {
                guard let resolvedMeta = meta(for: resolvedName) else {
                    return .failure(.routeNotFound(routeName: request.routeName))
                }
                return doValidate(request: request, meta: resolvedMeta)
            }
            return .failure(.routeNotFound(routeName: request.routeName))
        }
        return doValidate(request: request, meta: meta)
    }

    private func doValidate(request: RouteRequest, meta: RouteMeta) -> Result<Void, RouteError> {
        if !meta.requiredParams.isEmpty {
            let missing = meta.requiredParams.filter { request.params[$0] == nil }
            if !missing.isEmpty {
                return .failure(.invalidParams(routeName: meta.routeName, missing: missing))
            }
        }

        if meta.needLogin {
            if !UserSession.shared.isLoggedIn {
                return .failure(.notLogin(routeName: meta.routeName))
            }
        }

        if request.version < meta.version {
            return .failure(.illegalSource(source: request.source, details: "route version mismatch: request=\(request.version) meta=\(meta.version)"))
        }

        if request.source == .deeplink || request.source == .h5 || request.source == .qrcode {
            if !DeepLinkSecurityPolicy.shared.isTrusted(route: meta.routeName, params: request.params) {
                return .failure(.illegalSource(source: request.source, details: "untrusted deeplink target"))
            }
        }

        return .success(())
    }

    func resolveMeta(from request: inout RouteRequest) -> RouteMeta? {
        if let direct = meta(for: request.routeName) {
            applyMeta(direct, to: &request)
            return direct
        }
        if let resolvedName = routeName(forPath: request.path),
           let resolved = meta(for: resolvedName) {
            request.routeName = resolvedName
            applyMeta(resolved, to: &request)
            return resolved
        }
        return nil
    }

    private func applyMeta(_ meta: RouteMeta, to request: inout RouteRequest) {
        request.container = meta.container
        request.needLogin = meta.needLogin
        request.version = meta.version
        if request.animation == .default { request.animation = meta.animation }
        if request.presentMode == .push { request.presentMode = meta.presentMode }
    }

    // MARK: - Deeplink Parser

    func parseDeeplink(_ url: URL, source: RouteSource = .deeplink) -> RouteRequest? {
        let path = url.path.isEmpty ? "/" : url.path
        var params: [String: Any] = [:]
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            for item in queryItems {
                if let value = item.value {
                    params[item.name] = value
                }
            }
        }
        let routeName = routeName(forPath: path) ?? path
        return RouteRequest(
            routeName: routeName,
            path: path,
            params: params,
            source: source,
            sourcePage: source.rawValue
        )
    }

    // MARK: - Route Registrations

    private func registerDefaultRoutes() {

        register(meta: RouteMeta(
            routeName: "channel_demos",
            path: "/channel_demos",
            container: .flutter,
            needLogin: false,
            version: 1,
            animation: .default,
            presentMode: .push,
            description: "Flutter Channel 四种通信演示首页",
            requiredParams: []
        ))

        register(meta: RouteMeta(
            routeName: "method_channel_demo",
            path: "/method_channel",
            container: .flutter,
            needLogin: false,
            version: 1,
            animation: .slideLeft,
            presentMode: .push,
            description: "MethodChannel 演示页",
            requiredParams: []
        ))

        register(meta: RouteMeta(
            routeName: "event_channel_demo",
            path: "/event_channel",
            container: .flutter,
            needLogin: false,
            version: 1,
            animation: .slideLeft,
            presentMode: .push,
            description: "EventChannel 演示页",
            requiredParams: []
        ))

        register(meta: RouteMeta(
            routeName: "basic_message_demo",
            path: "/basic_message",
            container: .flutter,
            needLogin: false,
            version: 1,
            animation: .slideLeft,
            presentMode: .push,
            description: "BasicMessageChannel 演示页",
            requiredParams: []
        ))

        register(meta: RouteMeta(
            routeName: "platform_view_demo",
            path: "/platform_view",
            container: .flutter,
            needLogin: false,
            version: 1,
            animation: .slideLeft,
            presentMode: .push,
            description: "PlatformView 动态样式控制演示页",
            requiredParams: []
        ))

        register(meta: RouteMeta(
            routeName: "counter_demo",
            path: "/counter",
            container: .flutter,
            needLogin: false,
            version: 1,
            animation: .slideLeft,
            presentMode: .push,
            description: "Flutter 计数器 + pushForResult 演示",
            requiredParams: []
        ))

        register(meta: RouteMeta(
            routeName: "native_home",
            path: "/native/home",
            container: .native,
            needLogin: false,
            version: 1,
            animation: .default,
            presentMode: .push,
            description: "iOS 原生首页",
            requiredParams: []
        ))

        register(meta: RouteMeta(
            routeName: "native_page",
            path: "/native/page",
            container: .native,
            needLogin: false,
            version: 1,
            animation: .slideLeft,
            presentMode: .push,
            description: "iOS 原生详情页 (Flutter→Native 跳转目标)",
            requiredParams: []
        ))

        register(meta: RouteMeta(
            routeName: "user_profile",
            path: "/user/profile",
            container: .flutter,
            needLogin: true,
            version: 1,
            animation: .slideUp,
            presentMode: .present,
            description: "用户个人中心（需登录）",
            requiredParams: ["userId"]
        ))

        register(meta: RouteMeta(
            routeName: "login",
            path: "/login",
            container: .flutter,
            needLogin: false,
            version: 1,
            animation: .slideUp,
            presentMode: .present,
            description: "登录页（未登录兜底）",
            requiredParams: []
        ))

        register(meta: RouteMeta(
            routeName: "route_error",
            path: "/error/route",
            container: .native,
            needLogin: false,
            version: 1,
            animation: .fade,
            presentMode: .push,
            description: "路由错误兜底页",
            requiredParams: []
        ))
    }
}

// MARK: - Supporting Singletons (Mocked)

final class UserSession {
    static let shared = UserSession()
    var isLoggedIn: Bool = false
    var pendingRouteAfterLogin: RouteRequest?
    private init() {}
}

final class DeepLinkSecurityPolicy {
    static let shared = DeepLinkSecurityPolicy()

    private let allowedRoutesFromExternal: Set<String> = [
        "channel_demos",
        "native_page",
        "route_error",
        "login"
    ]

    private let disallowedParamPrefixes = ["file://", "javascript:", "data:"]

    private init() {}

    func isTrusted(route: String, params: [String: Any]) -> Bool {
        guard allowedRoutesFromExternal.contains(route) else { return false }
        for (_, value) in params {
            if let stringValue = value as? String {
                let lowercased = stringValue.lowercased()
                for prefix in disallowedParamPrefixes {
                    if lowercased.hasPrefix(prefix) { return false }
                }
            }
        }
        return true
    }
}
