import Foundation

enum RouteEvent: String {
    case openStart = "route_open_start"
    case openSuccess = "route_open_success"
    case openFail = "route_open_fail"
    case popStart = "route_pop_start"
    case popSuccess = "route_pop_success"
    case resultReturned = "route_result_returned"
    case engineWarmup = "route_engine_warmup"
    case fallbackError = "route_fallback_error"
}

struct RouteTrace {
    let event: RouteEvent
    let requestId: String
    let routeName: String
    let path: String
    let container: String
    let sourcePage: String
    let targetPage: String
    let paramsDigest: String
    let startTime: Date
    var endTime: Date?
    var durationMs: Int64?
    var result: String?
    var failReason: String?
    var failCode: String?
    var extra: [String: String]

    init(
        event: RouteEvent,
        requestId: String,
        routeName: String,
        path: String,
        container: String,
        sourcePage: String,
        targetPage: String,
        params: [String: Any]
    ) {
        self.event = event
        self.requestId = requestId
        self.routeName = routeName
        self.path = path
        self.container = container
        self.sourcePage = sourcePage
        self.targetPage = targetPage
        self.paramsDigest = RouteTrace.makeDigest(params)
        self.startTime = Date()
        self.endTime = nil
        self.durationMs = nil
        self.result = nil
        self.failReason = nil
        self.failCode = nil
        self.extra = [:]
    }

    mutating func markSuccess() {
        endTime = Date()
        durationMs = RouteTrace.diffMs(from: startTime, to: endTime!)
        result = "success"
    }

    mutating func markFail(error: RouteError) {
        endTime = Date()
        durationMs = RouteTrace.diffMs(from: startTime, to: endTime!)
        result = "fail"
        failCode = error.errorCode
        failReason = error.description
    }

    private static func diffMs(from start: Date, to end: Date) -> Int64 {
        Int64(end.timeIntervalSince(start) * 1000)
    }

    private static func makeDigest(_ params: [String: Any]) -> String {
        let keys = params.keys.sorted()
        var parts: [String] = []
        for key in keys {
            let value = params[key] ?? ""
            let valueStr: String
            if let v = value as? String {
                valueStr = v.count > 64 ? String(v.prefix(64)) + "..." : v
            } else {
                valueStr = "\(value)"
            }
            parts.append("\(key)=\(valueStr)")
        }
        return parts.joined(separator: "&")
    }
}

protocol RouteAnalyticsSink: AnyObject {
    func emit(trace: RouteTrace)
}

final class PrintAnalyticsSink: RouteAnalyticsSink {
    static let shared = PrintAnalyticsSink()
    private init() {}

    func emit(trace: RouteTrace) {
        var log = "[RouteAnalytics] event=\(trace.event.rawValue)"
        log += " | requestId=\(trace.requestId)"
        log += " | route=\(trace.routeName)(\(trace.path))"
        log += " | \(trace.sourcePage) → \(trace.targetPage)"
        log += " | container=\(trace.container)"
        if let d = trace.durationMs { log += " | cost=\(d)ms" }
        if let r = trace.result { log += " | result=\(r)" }
        if let code = trace.failCode { log += " | failCode=\(code)" }
        if let reason = trace.failReason { log += " | reason=\(reason)" }
        if !trace.extra.isEmpty {
            log += " | extra=\(trace.extra)"
        }
        #if DEBUG
        print(log)
        #endif
    }
}

final class RouteLogger {
    static let shared = RouteLogger()
    private let queue = DispatchQueue(label: "com.maocf.router.logger")
    private var pendingTraces: [String: RouteTrace] = [:]
    private var sinks: [RouteAnalyticsSink] = [PrintAnalyticsSink.shared]

    private(set) var successCount: Int64 = 0
    private(set) var failCount: Int64 = 0
    private(set) var failureTopList: [(code: String, count: Int64)] = []
    private var failureCounter: [String: Int64] = [:]
    private var flutterOpenDurations: [Int64] = []

    private init() {}

    func addSink(_ sink: RouteAnalyticsSink) {
        queue.sync { sinks.append(sink) }
    }

    func beginOpen(request: RouteRequest) {
        let trace = RouteTrace(
            event: .openStart,
            requestId: request.requestId,
            routeName: request.routeName,
            path: request.path,
            container: request.container.rawValue,
            sourcePage: request.sourcePage,
            targetPage: request.routeName,
            params: request.params
        )
        queue.sync {
            pendingTraces[request.requestId] = trace
            emit(trace)
        }
    }

    func endOpenSuccess(request: RouteRequest, extra: [String: String] = [:]) {
        queue.sync {
            guard var trace = pendingTraces.removeValue(forKey: request.requestId) else { return }
            trace.event = .openSuccess
            trace.extra.merge(extra) { _, new in new }
            trace.markSuccess()
            successCount += 1
            if request.container == .flutter, let dur = trace.durationMs {
                flutterOpenDurations.append(dur)
                if flutterOpenDurations.count > 500 { flutterOpenDurations.removeFirst() }
            }
            emit(trace)
        }
    }

    func endOpenFail(request: RouteRequest, error: RouteError, extra: [String: String] = [:]) {
        queue.sync {
            guard var trace = pendingTraces.removeValue(forKey: request.requestId) else {
                var fallback = RouteTrace(
                    event: .openFail,
                    requestId: request.requestId,
                    routeName: request.routeName,
                    path: request.path,
                    container: request.container.rawValue,
                    sourcePage: request.sourcePage,
                    targetPage: request.routeName,
                    params: request.params
                )
                fallback.extra = extra
                fallback.markFail(error: error)
                failCount += 1
                recordFailure(code: error.errorCode)
                emit(fallback)
                return
            }
            trace.event = .openFail
            trace.extra.merge(extra) { _, new in new }
            trace.markFail(error: error)
            failCount += 1
            recordFailure(code: error.errorCode)
            emit(trace)
        }
    }

    func logPop(fromRoute: String, toRoute: String, container: String, requestId: String, success: Bool, reason: String? = nil) {
        var trace = RouteTrace(
            event: success ? .popSuccess : .popStart,
            requestId: requestId,
            routeName: fromRoute,
            path: "",
            container: container,
            sourcePage: fromRoute,
            targetPage: toRoute,
            params: [:]
        )
        if success {
            trace.markSuccess()
        } else if let r = reason {
            trace.result = r
        }
        queue.sync { emit(trace) }
    }

    func logResult(requestId: String, routeName: String, payloadSize: Int, cancelled: Bool) {
        var trace = RouteTrace(
            event: .resultReturned,
            requestId: requestId,
            routeName: routeName,
            path: "",
            container: "hybrid",
            sourcePage: routeName,
            targetPage: "callback",
            params: ["payloadSize": payloadSize, "cancelled": cancelled]
        )
        trace.markSuccess()
        trace.extra["cancelled"] = "\(cancelled)"
        trace.extra["payloadSize"] = "\(payloadSize)"
        queue.sync { emit(trace) }
    }

    func logFallback(requestId: String, originalRoute: String, fallbackRoute: String, error: RouteError) {
        var trace = RouteTrace(
            event: .fallbackError,
            requestId: requestId,
            routeName: originalRoute,
            path: "",
            container: "fallback",
            sourcePage: originalRoute,
            targetPage: fallbackRoute,
            params: ["fallback": fallbackRoute]
        )
        trace.markFail(error: error)
        queue.sync { emit(trace) }
    }

    func snapshot() -> [String: Any] {
        queue.sync {
            var result: [String: Any] = [:]
            result["successCount"] = successCount
            result["failCount"] = failCount
            result["total"] = successCount + failCount
            let total = successCount + failCount
            result["successRate"] = total > 0 ? Double(successCount) / Double(total) : 1.0
            result["failureTop"] = failureTopList
            if !flutterOpenDurations.isEmpty {
                let sorted = flutterOpenDurations.sorted()
                result["flutterAvgMs"] = sorted.reduce(0, +) / Int64(sorted.count)
                result["flutterP95Ms"] = sorted[Int(Double(sorted.count) * 0.95)]
                result["flutterP99Ms"] = sorted[Int(Double(sorted.count) * 0.99)]
                result["flutterSampleCount"] = sorted.count
            }
            return result
        }
    }

    private func recordFailure(code: String) {
        failureCounter[code, default: 0] += 1
        failureTopList = failureCounter.map { (code: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
            .prefix(10)
            .map { $0 }
    }

    private func emit(_ trace: RouteTrace) {
        for sink in sinks {
            sink.emit(trace: trace)
        }
    }
}
