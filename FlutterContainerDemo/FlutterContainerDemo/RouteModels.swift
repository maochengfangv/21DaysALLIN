import UIKit
import Flutter

// MARK: - 路由协议层：统一路由对象定义

enum RouteContainer: String {
    case native
    case flutter
}

enum RoutePresentMode: String {
    case push
    case present
    case replace
}

enum RouteAnimation: String {
    case `default`
    case none
    case fade
    case slideUp
    case slideLeft
}

enum RouteSource: String {
    case inner
    case deeplink
    case push
    case qrcode
    case h5
    case unknown
}

struct RouteMeta {
    let routeName: String
    let path: String
    let container: RouteContainer
    let needLogin: Bool
    let version: Int
    let animation: RouteAnimation
    let presentMode: RoutePresentMode
    let description: String
    let requiredParams: [String]
}

struct RouteRequest {
    var routeName: String
    var path: String
    var params: [String: Any]
    var pageId: String
    var requestId: String
    var container: RouteContainer
    var needLogin: Bool
    var version: Int
    var animation: RouteAnimation
    var presentMode: RoutePresentMode
    var source: RouteSource
    var sourcePage: String
    var extra: [String: Any]

    private static var requestIdCounter: Int64 = 0
    private static let requestIdLock = NSLock()

    init(
        routeName: String,
        path: String,
        params: [String: Any] = [:],
        container: RouteContainer = .flutter,
        needLogin: Bool = false,
        version: Int = 1,
        animation: RouteAnimation = .default,
        presentMode: RoutePresentMode = .push,
        source: RouteSource = .inner,
        sourcePage: String = "unknown",
        extra: [String: Any] = [:]
    ) {
        self.routeName = routeName
        self.path = path
        self.params = params
        self.pageId = UUID().uuidString
        self.requestId = RouteRequest.generateRequestId()
        self.container = container
        self.needLogin = needLogin
        self.version = version
        self.animation = animation
        self.presentMode = presentMode
        self.source = source
        self.sourcePage = sourcePage
        self.extra = extra
    }

    private static func generateRequestId() -> String {
        requestIdLock.lock()
        defer { requestIdLock.unlock() }
        requestIdCounter += 1
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        return "req_\(timestamp)_\(requestIdCounter)"
    }

    func toChannelArguments() -> [String: Any] {
        [
            "routeName": routeName,
            "path": path,
            "params": params,
            "pageId": pageId,
            "requestId": requestId,
            "container": container.rawValue,
            "needLogin": needLogin,
            "version": version,
            "animation": animation.rawValue,
            "presentMode": presentMode.rawValue,
            "source": source.rawValue,
            "sourcePage": sourcePage
        ]
    }
}

struct RouteResult {
    let requestId: String
    let pageId: String
    let routeName: String
    let payload: Any?
    let isCancelled: Bool

    init(requestId: String, pageId: String, routeName: String, payload: Any?, isCancelled: Bool = false) {
        self.requestId = requestId
        self.pageId = pageId
        self.routeName = routeName
        self.payload = payload
        self.isCancelled = isCancelled
    }
}

enum RouteError: Error, CustomStringConvertible {
    case routeNotFound(routeName: String)
    case invalidParams(routeName: String, missing: [String])
    case notLogin(routeName: String)
    case engineNotReady(routeName: String)
    case flutterPageNotFound(routeName: String, path: String)
    case duplicateRequest(requestId: String)
    case illegalSource(source: RouteSource, details: String)
    case containerNotFound(routeName: String)
    case popStackCorrupted(details: String)
    case userCancelled

    var description: String {
        switch self {
        case .routeNotFound(let name):
            return "Route not found: \(name)"
        case .invalidParams(let name, let missing):
            return "Invalid params for \(name), missing: \(missing.joined(separator: ", "))"
        case .notLogin(let name):
            return "Need login for route: \(name)"
        case .engineNotReady(let name):
            return "Flutter engine not ready for: \(name)"
        case .flutterPageNotFound(let name, let path):
            return "Flutter page not found: \(name) (\(path))"
        case .duplicateRequest(let reqId):
            return "Duplicate route request: \(reqId)"
        case .illegalSource(let source, let details):
            return "Illegal source \(source.rawValue): \(details)"
        case .containerNotFound(let name):
            return "No container handler for: \(name)"
        case .popStackCorrupted(let details):
            return "Pop stack corrupted: \(details)"
        case .userCancelled:
            return "User cancelled route"
        }
    }

    var errorCode: String {
        switch self {
        case .routeNotFound: return "E_ROUTE_001"
        case .invalidParams: return "E_ROUTE_002"
        case .notLogin: return "E_ROUTE_003"
        case .engineNotReady: return "E_ROUTE_004"
        case .flutterPageNotFound: return "E_ROUTE_005"
        case .duplicateRequest: return "E_ROUTE_006"
        case .illegalSource: return "E_ROUTE_007"
        case .containerNotFound: return "E_ROUTE_008"
        case .popStackCorrupted: return "E_ROUTE_009"
        case .userCancelled: return "E_ROUTE_010"
        }
    }
}

typealias RouteResultCallback = (RouteResult) -> Void
typealias RouteCompletion = (Result<Void, RouteError>) -> Void

final class PendingRequestStore {
    static let shared = PendingRequestStore()
    private let queue = DispatchQueue(label: "com.maocf.router.pending")
    private var callbacks: [String: RouteResultCallback] = [:]
    private var requests: [String: RouteRequest] = [:]
    private var lastOpenTimestamp: [String: TimeInterval] = [:]

    private init() {}

    func store(request: RouteRequest, callback: RouteResultCallback?) {
        queue.sync {
            requests[request.requestId] = request
            callbacks[request.requestId] = callback
            lastOpenTimestamp[request.routeName] = Date().timeIntervalSince1970
        }
    }

    func resolveResult(_ result: RouteResult) {
        var callback: RouteResultCallback?
        queue.sync {
            callback = callbacks.removeValue(forKey: result.requestId)
            requests.removeValue(forKey: result.requestId)
        }
        DispatchQueue.main.async {
            callback?(result)
        }
    }

    func request(for requestId: String) -> RouteRequest? {
        queue.sync { requests[requestId] }
    }

    func isDuplicateOpen(routeName: String, window: TimeInterval = 0.5) -> Bool {
        queue.sync {
            guard let last = lastOpenTimestamp[routeName] else { return false }
            return Date().timeIntervalSince1970 - last < window
        }
    }

    func removeRequest(requestId: String) {
        queue.sync {
            callbacks.removeValue(forKey: requestId)
            requests.removeValue(forKey: requestId)
        }
    }

    var pendingCount: Int {
        queue.sync { requests.count }
    }
}
