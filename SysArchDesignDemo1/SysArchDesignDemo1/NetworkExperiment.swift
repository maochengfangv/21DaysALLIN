import Foundation

// 这个文件实现“本地请求拦截器 + TTL 缓存 + 缓存击穿/SingleFlight 对照实验 + Metrics”。
// 选型：B（URLSession wrapper + interceptor chain）风格。
// - Interceptor 负责对“回源请求”注入延迟/超时/错误，模拟网络环境。
// - Transport 负责真正产出响应（这里用本地源站 LocalOriginTransport，不依赖真实网络）。
// 严格行为：
// - “超时”定义：注入延迟 injectedDelayMs > timeoutThresholdMs 时，返回 URLError(.timedOut)，并计入 metrics.timeout。
// - 缓存策略：仅成功响应写入缓存；失败/超时/5xx 不写入（无 negative cache）。

typealias TransportCompletion = (Result<(Data, URLResponse), Error>) -> Void

protocol Transport {
    func execute(_ request: URLRequest, completion: @escaping TransportCompletion)
}

protocol Interceptor {
    func intercept(_ request: URLRequest, next: @escaping (URLRequest, @escaping TransportCompletion) -> Void, completion: @escaping TransportCompletion)
}

struct InjectionConfig: Equatable {
    var baseDelayMs: Int
    var jitterMs: Int
    var timeoutThresholdMs: Int
    var timeoutProbability: Double
    var errorProbability: Double
}

struct ExperimentConfig: Equatable {
    var concurrency: Int
    var ttl: TimeInterval
    var injection: InjectionConfig
    var enableSingleFlight: Bool
}

struct HTTPStatusError: Error {
    let statusCode: Int
}

// Metrics 口径：
// - cacheHit/cacheMiss：以 fetch(url) 是否命中 TTLCache 为准
// - originFetch：进入 LocalOriginTransport 即计一次（用于观察击穿/合并效果）
// - timeout：TimeoutInjector 判定超时即计一次
// - http5xx：ErrorInjector 注入 5xx 或响应解析为 5xx
// - latency：一次 fetch 的端到端耗时（包含缓存查找、等待 singleflight、拦截器注入延迟）
final class Metrics {
    struct Snapshot {
        let cacheHit: Int
        let cacheMiss: Int
        let originFetch: Int
        let timeout: Int
        let http5xx: Int
        let avgLatencyMs: Double
        let p95LatencyMs: Double
        let requestCount: Int
    }

    private let lock = NSLock()
    private var cacheHit: Int = 0
    private var cacheMiss: Int = 0
    private var originFetch: Int = 0
    private var timeout: Int = 0
    private var http5xx: Int = 0
    private var latenciesMs: [Double] = []

    func reset() {
        lock.lock()
        cacheHit = 0
        cacheMiss = 0
        originFetch = 0
        timeout = 0
        http5xx = 0
        latenciesMs.removeAll(keepingCapacity: true)
        lock.unlock()
    }

    func recordCacheHit() {
        lock.lock()
        cacheHit += 1
        lock.unlock()
    }

    func recordCacheMiss() {
        lock.lock()
        cacheMiss += 1
        lock.unlock()
    }

    func recordOriginFetch() {
        lock.lock()
        originFetch += 1
        lock.unlock()
    }

    func recordTimeout() {
        lock.lock()
        timeout += 1
        lock.unlock()
    }

    func recordHTTP5xx() {
        lock.lock()
        http5xx += 1
        lock.unlock()
    }

    func recordLatencyMs(_ value: Double) {
        lock.lock()
        latenciesMs.append(value)
        lock.unlock()
    }

    func snapshot() -> Snapshot {
        lock.lock()
        let hit = cacheHit
        let miss = cacheMiss
        let origin = originFetch
        let to = timeout
        let s5xx = http5xx
        let lat = latenciesMs
        lock.unlock()

        let count = lat.count
        let avg: Double
        let p95: Double

        if count == 0 {
            avg = 0
            p95 = 0
        } else {
            avg = lat.reduce(0, +) / Double(count)
            let sorted = lat.sorted()
            let idx = max(0, min(sorted.count - 1, Int(ceil(0.95 * Double(sorted.count))) - 1))
            p95 = sorted[idx]
        }

        return Snapshot(
            cacheHit: hit,
            cacheMiss: miss,
            originFetch: origin,
            timeout: to,
            http5xx: s5xx,
            avgLatencyMs: avg,
            p95LatencyMs: p95,
            requestCount: count
        )
    }
}

// TTL 缓存：
// - get 时如果已过期会立即移除并返回 nil
// - set 写入时按 ttl 计算过期时间
// - expire(key) 用于确保实验可重复复现（强制过期）
final class TTLCacheStore {
    private struct Entry {
        let data: Data
        let expiry: Date
    }

    private let lock = NSLock()
    private var map: [String: Entry] = [:]

    func get(_ key: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }

        guard let entry = map[key] else { return nil }
        if Date() >= entry.expiry {
            map.removeValue(forKey: key)
            return nil
        }
        return entry.data
    }

    func set(_ key: String, data: Data, ttl: TimeInterval) {
        lock.lock()
        map[key] = Entry(data: data, expiry: Date().addingTimeInterval(ttl))
        lock.unlock()
    }

    func expire(_ key: String) {
        lock.lock()
        map.removeValue(forKey: key)
        lock.unlock()
    }

    func reset() {
        lock.lock()
        map.removeAll(keepingCapacity: true)
        lock.unlock()
    }
}

// SingleFlight（并发合并）：同一个 key 在同一时刻只允许 1 次 work 运行。
// - 后续并发请求加入 waiters 队列，等待首个 work 完成后复用同一结果。
// - reset 用于避免全局状态污染，支持一键重复实验。
final class SingleFlight {
    typealias Work = (@escaping TransportCompletion) -> Void

    private let lock = NSLock()
    private var inflight: [String: [TransportCompletion]] = [:]

    func reset() {
        lock.lock()
        inflight.removeAll(keepingCapacity: true)
        lock.unlock()
    }

    func `do`(key: String, work: @escaping Work, completion: @escaping TransportCompletion) {
        lock.lock()
        if inflight[key] != nil {
            inflight[key]?.append(completion)
            lock.unlock()
            return
        } else {
            inflight[key] = [completion]
            lock.unlock()
        }

        work { [weak self] result in
            guard let self else { return }
            self.lock.lock()
            let waiters = self.inflight[key] ?? []
            self.inflight.removeValue(forKey: key)
            self.lock.unlock()

            waiters.forEach { $0(result) }
        }
    }
}

final class NetworkClient {
    private let transport: Transport
    private let interceptors: [Interceptor]

    init(transport: Transport, interceptors: [Interceptor]) {
        self.transport = transport
        self.interceptors = interceptors
    }

    func data(for request: URLRequest, completion: @escaping TransportCompletion) {
        run(index: 0, request: request, completion: completion)
    }

    private func run(index: Int, request: URLRequest, completion: @escaping TransportCompletion) {
        if index >= interceptors.count {
            transport.execute(request, completion: completion)
            return
        }

        let interceptor = interceptors[index]
        interceptor.intercept(
            request,
            next: { [weak self] req, comp in
                self?.run(index: index + 1, request: req, completion: comp)
            },
            completion: completion
        )
    }
}

// TimeoutInjector：对“回源请求”注入延迟，并按阈值严格判定 timedOut。
// 注意：这里的 timeout 判定不是 URLSession 自带 timeoutInterval，而是“注入延迟 > 阈值”的可控实验定义。
final class TimeoutInjector: Interceptor {
    private let configProvider: () -> InjectionConfig
    private let metrics: Metrics
    private let queue: DispatchQueue

    init(configProvider: @escaping () -> InjectionConfig, metrics: Metrics, queue: DispatchQueue = DispatchQueue(label: "timeout.injector.queue")) {
        self.configProvider = configProvider
        self.metrics = metrics
        self.queue = queue
    }

    func intercept(_ request: URLRequest, next: @escaping (URLRequest, @escaping TransportCompletion) -> Void, completion: @escaping TransportCompletion) {
        let cfg = configProvider()

        let shouldForceTimeout = Double.random(in: 0..<1) < cfg.timeoutProbability
        let jitter = cfg.jitterMs > 0 ? Int.random(in: 0...cfg.jitterMs) : 0
        let injectedDelayMs = shouldForceTimeout ? (cfg.timeoutThresholdMs + 1 + jitter) : (cfg.baseDelayMs + jitter)

        let thresholdMs = max(cfg.timeoutThresholdMs, 0)
        let delayNs = UInt64(max(injectedDelayMs, 0)) * 1_000_000
        let thresholdNs = UInt64(thresholdMs) * 1_000_000

        next(request) { [weak self] result in
            guard let self else { return }

            if injectedDelayMs > thresholdMs {
                // 严格超时定义：注入延迟超过阈值时，直接在阈值时刻返回 timedOut，并记录 timeout 次数。
                self.queue.asyncAfter(deadline: .now() + .nanoseconds(Int(thresholdNs))) {
                    self.metrics.recordTimeout()
                    completion(.failure(URLError(.timedOut)))
                }
                return
            }

            // 未超过阈值：延迟到 injectedDelayMs 再返回“原始结果”（成功/失败都会被延迟）。
            self.queue.asyncAfter(deadline: .now() + .nanoseconds(Int(delayNs))) {
                completion(result)
            }
        }
    }
}

final class ErrorInjector: Interceptor {
    private let configProvider: () -> InjectionConfig
    private let metrics: Metrics

    init(configProvider: @escaping () -> InjectionConfig, metrics: Metrics) {
        self.configProvider = configProvider
        self.metrics = metrics
    }

    func intercept(_ request: URLRequest, next: @escaping (URLRequest, @escaping TransportCompletion) -> Void, completion: @escaping TransportCompletion) {
        let cfg = configProvider()
        if Double.random(in: 0..<1) < cfg.errorProbability {
            metrics.recordHTTP5xx()
            let url = request.url ?? URL(string: "https://example.local/")!
            let response = HTTPURLResponse(url: url, statusCode: 503, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            let body = Data("{\"error\":\"injected_5xx\"}".utf8)
            completion(.success((body, response)))
            return
        }
        next(request, completion)
    }
}

final class LocalOriginTransport: Transport {
    private let metrics: Metrics
    private let queue: DispatchQueue

    init(metrics: Metrics, queue: DispatchQueue = DispatchQueue(label: "local.origin.transport.queue")) {
        self.metrics = metrics
        self.queue = queue
    }

    func execute(_ request: URLRequest, completion: @escaping TransportCompletion) {
        metrics.recordOriginFetch()

        queue.async {
            let url = request.url ?? URL(string: "https://example.local/")!
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            let now = Date().timeIntervalSince1970
            let json = "{\"ok\":true,\"ts\":\(now),\"path\":\"\(url.path)\",\"query\":\"\(url.query ?? "")\"}"
            completion(.success((Data(json.utf8), response)))
        }
    }
}

// CachedFetcher：
// - 先查 TTLCache；命中则直接返回并计 cacheHit
// - 未命中：根据 enableSingleFlight 选择“全部回源（击穿）”或“合并回源（singleflight）”
// - 仅成功写缓存；失败/超时/5xx 不写缓存
final class CachedFetcher {
    private let client: NetworkClient
    private let cache: TTLCacheStore
    private let singleFlight: SingleFlight
    private let metrics: Metrics
    private let configProvider: () -> ExperimentConfig

    init(client: NetworkClient, cache: TTLCacheStore, singleFlight: SingleFlight, metrics: Metrics, configProvider: @escaping () -> ExperimentConfig) {
        self.client = client
        self.cache = cache
        self.singleFlight = singleFlight
        self.metrics = metrics
        self.configProvider = configProvider
    }

    func expire(url: URL) {
        cache.expire(url.absoluteString)
    }

    func fetch(url: URL, completion: @escaping (Result<Data, Error>) -> Void) {
        let key = url.absoluteString
        let start = CFAbsoluteTimeGetCurrent()

        if let cached = cache.get(key) {
            metrics.recordCacheHit()
            metrics.recordLatencyMs((CFAbsoluteTimeGetCurrent() - start) * 1000)
            completion(.success(cached))
            return
        }

        metrics.recordCacheMiss()

        let request = URLRequest(url: url)

        let work: SingleFlight.Work = { [weak self] done in
            guard let self else { return }
            self.client.data(for: request) { result in
                done(result)
            }
        }

        let finish: (Result<(Data, URLResponse), Error>) -> Void = { [weak self] result in
            guard let self else { return }

            let mapped: Result<Data, Error> = result.flatMap { (data, response) in
                if let http = response as? HTTPURLResponse, http.statusCode >= 500 {
                    return .failure(HTTPStatusError(statusCode: http.statusCode))
                }
                return .success(data)
            }

            if case .success(let data) = mapped {
                let ttl = self.configProvider().ttl
                self.cache.set(key, data: data, ttl: ttl)
            }

            self.metrics.recordLatencyMs((CFAbsoluteTimeGetCurrent() - start) * 1000)
            completion(mapped)
        }

        if configProvider().enableSingleFlight {
            singleFlight.do(key: key, work: work, completion: finish)
        } else {
            work(finish)
        }
    }
}

final class ExperimentEnvironment {
    private final class ConfigBox {
        private let lock = NSLock()
        private var config: ExperimentConfig

        init(_ config: ExperimentConfig) {
            self.config = config
        }

        func get() -> ExperimentConfig {
            lock.lock()
            let c = config
            lock.unlock()
            return c
        }

        func set(_ newConfig: ExperimentConfig) {
            lock.lock()
            config = newConfig
            lock.unlock()
        }
    }

    private let configBox: ConfigBox

    let baseURL: URL
    let metrics: Metrics
    private let cache: TTLCacheStore
    private let singleFlight: SingleFlight
    private let fetcher: CachedFetcher

    init(baseURL: URL, config: ExperimentConfig) {
        self.baseURL = baseURL

        let box = ConfigBox(config)
        self.configBox = box

        let metrics = Metrics()
        self.metrics = metrics

        let cache = TTLCacheStore()
        self.cache = cache

        let singleFlight = SingleFlight()
        self.singleFlight = singleFlight

        let injectionProvider: () -> InjectionConfig = {
            box.get().injection
        }

        let transport = LocalOriginTransport(metrics: metrics)
        let client = NetworkClient(
            transport: transport,
            interceptors: [
                ErrorInjector(configProvider: injectionProvider, metrics: metrics),
                TimeoutInjector(configProvider: injectionProvider, metrics: metrics)
            ]
        )

        let configProvider: () -> ExperimentConfig = {
            box.get()
        }

        self.fetcher = CachedFetcher(client: client, cache: cache, singleFlight: singleFlight, metrics: metrics, configProvider: configProvider)
    }

    func updateConfig(_ newConfig: ExperimentConfig) {
        configBox.set(newConfig)
    }

    func currentConfig() -> ExperimentConfig {
        configBox.get()
    }

    func resetAll() {
        metrics.reset()
        cache.reset()
        singleFlight.reset()
    }

    func resetMetricsOnly() {
        metrics.reset()
    }

    func expire() {
        fetcher.expire(url: baseURL)
    }

    func expire(key: String) {
        cache.expire(key)
    }

    func fetch(completion: @escaping (Result<Data, Error>) -> Void) {
        fetcher.fetch(url: baseURL, completion: completion)
    }
}

// ExperimentRunner：编排对照实验用例。
// - Case1：TTL 未过期时多次请求命中缓存（origin 基本不增长）
// - Case2：TTL 过期 + N 并发 + singleflight=OFF → origin ≈ N（击穿）
// - Case3：TTL 过期 + N 并发 + singleflight=ON  → origin ≈ 1（合并）
final class ExperimentRunner {
    private let environment: ExperimentEnvironment

    init(environment: ExperimentEnvironment) {
        self.environment = environment
    }

    func runThreeCases(concurrency: Int, completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var outputs: [String] = []

            let base = self.environment.currentConfig()
            outputs.append(self.formatHeader(config: base, concurrency: concurrency))

            outputs.append(self.runCase1SequentialWarmAndHit())
            outputs.append(self.runCase2Breakdown(concurrency: concurrency))
            outputs.append(self.runCase3SingleFlight(concurrency: concurrency))

            completion(outputs.joined(separator: "\n\n"))
        }
    }

    func runSingleCase(name: String, concurrency: Int, enableSingleFlight: Bool, completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var cfg = self.environment.currentConfig()
            cfg.enableSingleFlight = enableSingleFlight
            self.environment.updateConfig(cfg)

            self.environment.resetMetricsOnly()
            self.environment.expire()

            let totalStart = CFAbsoluteTimeGetCurrent()
            self.runConcurrentFetches(count: concurrency)
            let totalMs = (CFAbsoluteTimeGetCurrent() - totalStart) * 1000

            let snap = self.environment.metrics.snapshot()
            completion(self.formatCase(name: name, snapshot: snap, totalMs: totalMs))
        }
    }

    private func runCase1SequentialWarmAndHit() -> String {
        var cfg = environment.currentConfig()
        cfg.enableSingleFlight = true
        environment.updateConfig(cfg)

        environment.resetMetricsOnly()
        environment.expire()

        let totalStart = CFAbsoluteTimeGetCurrent()

        waitOneFetch()
        for _ in 0..<5 {
            waitOneFetch()
        }

        let totalMs = (CFAbsoluteTimeGetCurrent() - totalStart) * 1000
        let snap = environment.metrics.snapshot()
        return formatCase(name: "Case1 TTL未过期：连续请求命中缓存", snapshot: snap, totalMs: totalMs)
    }

    private func runCase2Breakdown(concurrency: Int) -> String {
        var cfg = environment.currentConfig()
        cfg.enableSingleFlight = false
        environment.updateConfig(cfg)

        environment.resetMetricsOnly()
        environment.expire()

        let totalStart = CFAbsoluteTimeGetCurrent()
        runConcurrentFetches(count: concurrency)
        let totalMs = (CFAbsoluteTimeGetCurrent() - totalStart) * 1000

        let snap = environment.metrics.snapshot()
        return formatCase(name: "Case2 TTL过期 + N并发 + singleflight=OFF（击穿）", snapshot: snap, totalMs: totalMs)
    }

    private func runCase3SingleFlight(concurrency: Int) -> String {
        var cfg = environment.currentConfig()
        cfg.enableSingleFlight = true
        environment.updateConfig(cfg)

        environment.resetMetricsOnly()
        environment.expire()

        let totalStart = CFAbsoluteTimeGetCurrent()
        runConcurrentFetches(count: concurrency)
        let totalMs = (CFAbsoluteTimeGetCurrent() - totalStart) * 1000

        let snap = environment.metrics.snapshot()
        return formatCase(name: "Case3 TTL过期 + N并发 + singleflight=ON（合并回源）", snapshot: snap, totalMs: totalMs)
    }

    private func waitOneFetch() {
        let sema = DispatchSemaphore(value: 0)
        environment.fetch { _ in
            sema.signal()
        }
        sema.wait()
    }

    private func runConcurrentFetches(count: Int) {
        let group = DispatchGroup()
        for _ in 0..<max(count, 1) {
            group.enter()
            environment.fetch { _ in
                group.leave()
            }
        }
        group.wait()
    }

    private func formatHeader(config: ExperimentConfig, concurrency: Int) -> String {
        let inj = config.injection
        return [
            "[Config]",
            "N=\(concurrency), TTL=\(String(format: "%.3f", config.ttl))s, singleflight(UI)=\(config.enableSingleFlight)",
            "delay=base \(inj.baseDelayMs)ms + jitter 0~\(inj.jitterMs)ms, timeoutThreshold=\(inj.timeoutThresholdMs)ms, pTimeout=\(String(format: "%.2f", inj.timeoutProbability)), p5xx=\(String(format: "%.2f", inj.errorProbability))"
        ].joined(separator: " ")
    }

    private func formatCase(name: String, snapshot: Metrics.Snapshot, totalMs: Double) -> String {
        return [
            "[\(name)]",
            "cache hit/miss=\(snapshot.cacheHit)/\(snapshot.cacheMiss), origin=\(snapshot.originFetch), timeout=\(snapshot.timeout), 5xx=\(snapshot.http5xx)",
            "lat(ms) avg=\(String(format: "%.2f", snapshot.avgLatencyMs)), p95=\(String(format: "%.2f", snapshot.p95LatencyMs)), n=\(snapshot.requestCount), total=\(String(format: "%.2f", totalMs))"
        ].joined(separator: "\n")
    }
}