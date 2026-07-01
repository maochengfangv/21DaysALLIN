//
//  ViewController.swift
//  SingleFlightDemo
//
//  Created by maochengfang on 2026/7/1.
//

import UIKit

final class ViewController: UIViewController {
    private let logView = UITextView()
    private let singleFlightSwitch = UISwitch()

    private let repo = DemoRepository()
    private var logs: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "SingleFlightDemo"
        buildUI()
        render("ready")
    }

    private func buildUI() {
        logView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        logView.isEditable = false
        logView.backgroundColor = .secondarySystemBackground
        logView.layer.cornerRadius = 10

        let toggleTitle = UILabel()
        toggleTitle.text = "SingleFlight"
        toggleTitle.font = .systemFont(ofSize: 15, weight: .medium)

        singleFlightSwitch.isOn = repo.enableSingleFlight
        singleFlightSwitch.addTarget(self, action: #selector(onToggleSingleFlight), for: .valueChanged)

        let toggleRow = UIStackView(arrangedSubviews: [toggleTitle, singleFlightSwitch])
        toggleRow.axis = .horizontal
        toggleRow.spacing = 12
        toggleRow.alignment = .center

        let stack = UIStackView(arrangedSubviews: [toggleRow,
                                                  button("登录态/Token 刷新", #selector(onTokenRefreshBurst)),
                                                  button("用户信息/权限拉取", #selector(onMeBurst)),
                                                  button("配置中心/AB/灰度", #selector(onConfigBurst)),
                                                  button("热点资源详情（同 id）", #selector(onItemBurst)),
                                                  button("图片/多媒体元数据", #selector(onMediaMetaBurst)),
                                                  button("缓存失效回源（击穿）", #selector(onCacheFillBurst)),
                                                  button("磁盘/数据库 IO（非网络）", #selector(onDbReadBurst)),
                                                  logView])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            logView.heightAnchor.constraint(equalToConstant: 320)
        ])
    }

    private func button(_ title: String, _ action: Selector) -> UIButton {
        let v = UIButton(type: .system)
        v.setTitle(title, for: .normal)
        v.contentHorizontalAlignment = .leading
        v.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        v.addTarget(self, action: action, for: .touchUpInside)
        return v
    }

    @objc private func onToggleSingleFlight() {
        repo.enableSingleFlight = singleFlightSwitch.isOn
        render("singleflight = \(repo.enableSingleFlight)")
    }

    @objc private func onTokenRefreshBurst() {
        burst(tag: "refresh", count: 8) { done in
            self.repo.refreshToken(userId: "u1", authScope: "default", completion: done)
        }
    }

    @objc private func onMeBurst() {
        burst(tag: "me", count: 8) { done in
            self.repo.fetchMe(userId: "u1", authScope: "default", locale: "zh-Hans", completion: done)
        }
    }

    @objc private func onConfigBurst() {
        burst(tag: "config", count: 8) { done in
            self.repo.fetchConfig(userId: "u1", anonId: nil, locale: "zh-Hans", region: "CN", scene: "home", completion: done)
        }
    }

    @objc private func onItemBurst() {
        burst(tag: "item", count: 8) { done in
            self.repo.fetchItemDetail(resourceId: "42", userId: "u1", locale: "zh-Hans", region: "CN", fieldsMask: "base", completion: done)
        }
    }

    @objc private func onMediaMetaBurst() {
        burst(tag: "mediaMeta", count: 8) { done in
            self.repo.fetchMediaMeta(mediaId: "img_99", variant: "thumb", userId: "u1", authScope: "default", locale: "zh-Hans", completion: done)
        }
    }

    @objc private func onCacheFillBurst() {
        repo.expireCache(logicalKey: "feed_home")
        burst(tag: "cacheFill", count: 8) { done in
            self.repo.getOrLoadCache(logicalKey: "feed_home", userId: "u1", locale: "zh-Hans", region: "CN", ttlSeconds: 3, completion: done)
        }
    }

    @objc private func onDbReadBurst() {
        burst(tag: "dbRead", count: 8) { done in
            self.repo.dbRead(table: "user", primaryKey: "u1", projection: "id,name,role", completion: done)
        }
    }

    private func burst(tag: String, count: Int, work: @escaping (@escaping (Result<String, Error>) -> Void) -> Void) {
        (0..<count).forEach { idx in
            work { [weak self] result in
                guard let self else { return }
                DispatchQueue.main.async {
                    switch result {
                    case .success(let v):
                        self.render("\(tag)#\(idx) -> \(v)")
                    case .failure(let e):
                        self.render("\(tag)#\(idx) err -> \(type(of: e))")
                    }
                }
            }
        }
    }

    private func render(_ line: String) {
        let m = repo.snapshot()
        let header = "sf=\(repo.enableSingleFlight) origin=\(m.origin) coalesced=\(m.coalesced) inflightMax=\(m.inflightMax) ok=\(m.ok) fail=\(m.fail) timeout=\(m.timeout) dropW=\(m.dropTooManyWaiters) dropI=\(m.dropTooManyInflight) cancel=\(m.canceled) waitP95=\(m.waitP95ms)ms waitP99=\(m.waitP99ms)ms"
        logs.append(line)
        if logs.count > 18 { logs.removeFirst(logs.count - 18) }
        logView.text = ([header] + logs).joined(separator: "\n")
    }
}

private struct SingleFlightEvent {
    let key: String
    let waiters: Int
    let waitMs: Int
    let ok: Bool
}

private final class DemoMetrics {
    private let lock = NSLock()

    private(set) var origin: Int = 0
    private(set) var coalesced: Int = 0
    private(set) var inflightMax: Int = 0
    private(set) var ok: Int = 0
    private(set) var fail: Int = 0
    private(set) var timeout: Int = 0
    private(set) var dropTooManyWaiters: Int = 0
    private(set) var dropTooManyInflight: Int = 0
    private(set) var canceled: Int = 0

    private var waitSamplesMs: [Int] = []

    func onStart(inflight: Int) {
        lock.lock(); defer { lock.unlock() }
        origin += 1
        inflightMax = max(inflightMax, inflight)
    }

    func onJoin() {
        lock.lock(); defer { lock.unlock() }
        coalesced += 1
    }

    func onDrop(_ reason: SingleFlightDropReason) {
        lock.lock(); defer { lock.unlock() }
        switch reason {
        case .tooManyWaiters:
            dropTooManyWaiters += 1
        case .tooManyInflight:
            dropTooManyInflight += 1
        case .canceled:
            canceled += 1
        }
    }

    func onFinish(_ event: SingleFlightEvent, outcome: SingleFlightOutcome) {
        lock.lock(); defer { lock.unlock() }
        switch outcome {
        case .success:
            ok += 1
        case .failure:
            fail += 1
        case .timeout:
            fail += 1
            timeout += 1
        }
        waitSamplesMs.append(event.waitMs)
        if waitSamplesMs.count > 400 { waitSamplesMs.removeFirst(waitSamplesMs.count - 400) }
    }

    func snapshot() -> DemoMetricsSnapshot {
        lock.lock(); defer { lock.unlock() }
        let p95 = percentile(waitSamplesMs, 0.95)
        let p99 = percentile(waitSamplesMs, 0.99)
        return DemoMetricsSnapshot(origin: origin,
                                  coalesced: coalesced,
                                  inflightMax: inflightMax,
                                  ok: ok,
                                  fail: fail,
                                  timeout: timeout,
                                  dropTooManyWaiters: dropTooManyWaiters,
                                  dropTooManyInflight: dropTooManyInflight,
                                  canceled: canceled,
                                  waitP95ms: p95,
                                  waitP99ms: p99)
    }

    private func percentile(_ xs: [Int], _ p: Double) -> Int {
        guard !xs.isEmpty else { return 0 }
        let s = xs.sorted()
        let idx = min(max(Int(Double(s.count - 1) * p), 0), s.count - 1)
        return s[idx]
    }
}

private struct DemoMetricsSnapshot {
    let origin: Int
    let coalesced: Int
    let inflightMax: Int
    let ok: Int
    let fail: Int
    let timeout: Int
    let dropTooManyWaiters: Int
    let dropTooManyInflight: Int
    let canceled: Int
    let waitP95ms: Int
    let waitP99ms: Int
}

private enum SingleFlightError: Error {
    case timeout
    case tooManyWaiters
    case tooManyInflight
}

private enum SingleFlightDropReason {
    case tooManyWaiters
    case tooManyInflight
    case canceled
}

private enum SingleFlightOutcome {
    case success
    case failure
    case timeout
}

private struct SingleFlightOptions {
    var timeoutMs: Int
    var maxWaitersPerKey: Int
    var maxInflightKeys: Int

    static let `default` = SingleFlightOptions(timeoutMs: 1500, maxWaitersPerKey: 64, maxInflightKeys: 256)
}

private protocol SingleFlightObserver: AnyObject {
    func onStart(key: String, inflight: Int)
    func onJoin(key: String)
    func onDrop(key: String, reason: SingleFlightDropReason)
    func onFinish(key: String, waiters: Int, waitMs: Int, outcome: SingleFlightOutcome)
}

private final class MetricsObserver: SingleFlightObserver {
    private let metrics: DemoMetrics

    init(metrics: DemoMetrics) {
        self.metrics = metrics
    }

    func onStart(key: String, inflight: Int) {
        metrics.onStart(inflight: inflight)
    }

    func onJoin(key: String) {
        metrics.onJoin()
    }

    func onDrop(key: String, reason: SingleFlightDropReason) {
        metrics.onDrop(reason)
    }

    func onFinish(key: String, waiters: Int, waitMs: Int, outcome: SingleFlightOutcome) {
        let ok = (outcome == .success)
        metrics.onFinish(SingleFlightEvent(key: key, waiters: waiters, waitMs: waitMs, ok: ok), outcome: outcome)
    }
}

private final class SingleFlightTask {
    private let lock = NSLock()
    private var onCancel: (() -> Void)?

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        lock.lock(); defer { lock.unlock() }
        guard let c = onCancel else { return }
        onCancel = nil
        c()
    }

    static let noop = SingleFlightTask(onCancel: {})
}

private final class SingleFlight<Value> {
    private final class Entry {
        let startedAt: CFAbsoluteTime
        var callbacks: [UUID: (Result<Value, Error>) -> Void]
        var timer: DispatchSourceTimer?
        var finished = false

        init(startedAt: CFAbsoluteTime, callbacks: [UUID: @escaping (Result<Value, Error>) -> Void]) {
            self.startedAt = startedAt
            self.callbacks = callbacks
        }
    }

    private let lock = NSLock()
    private var inflight: [String: Entry] = [:]

    func run(key: String,
             options: SingleFlightOptions = .default,
             start: (@escaping (Result<Value, Error>) -> Void) -> Void,
             completion: @escaping (Result<Value, Error>) -> Void,
             observer: SingleFlightObserver? = nil) -> SingleFlightTask {
        let id = UUID()

        lock.lock()
        if let e = inflight[key] {
            if e.callbacks.count >= options.maxWaitersPerKey {
                lock.unlock()
                observer?.onDrop(key: key, reason: .tooManyWaiters)
                completion(.failure(SingleFlightError.tooManyWaiters))
                return .noop
            }
            e.callbacks[id] = completion
            lock.unlock()
            observer?.onJoin(key: key)
            return SingleFlightTask { [weak self] in
                self?.cancelCallback(key: key, id: id, observer: observer)
            }
        }

        if inflight.count >= options.maxInflightKeys {
            lock.unlock()
            observer?.onDrop(key: key, reason: .tooManyInflight)
            completion(.failure(SingleFlightError.tooManyInflight))
            return .noop
        }

        let entry = Entry(startedAt: CFAbsoluteTimeGetCurrent(), callbacks: [id: completion])
        inflight[key] = entry
        let inflightCount = inflight.count
        lock.unlock()
        observer?.onStart(key: key, inflight: inflightCount)

        if options.timeoutMs > 0 {
            let t = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
            t.schedule(deadline: .now() + .milliseconds(options.timeoutMs))
            t.setEventHandler { [weak self] in
                self?.finish(key: key, result: .failure(SingleFlightError.timeout), observer: observer)
            }
            lock.lock(); entry.timer = t; lock.unlock()
            t.resume()
        }

        start { [weak self] result in
            self?.finish(key: key, result: result, observer: observer)
        }

        return SingleFlightTask { [weak self] in
            self?.cancelCallback(key: key, id: id, observer: observer)
        }
    }

    private func cancelCallback(key: String, id: UUID, observer: SingleFlightObserver?) {
        lock.lock()
        guard let e = inflight[key] else {
            lock.unlock()
            return
        }
        let removed = e.callbacks.removeValue(forKey: id) != nil
        let shouldDropEntry = e.callbacks.isEmpty && !e.finished
        if shouldDropEntry {
            e.finished = true
            inflight.removeValue(forKey: key)
        }
        let timer = shouldDropEntry ? e.timer : nil
        lock.unlock()

        if removed { observer?.onDrop(key: key, reason: .canceled) }
        timer?.cancel()
    }

    private func finish(key: String, result: Result<Value, Error>, observer: SingleFlightObserver?) {
        let callbacks: [ (Result<Value, Error>) -> Void ]
        let waiters: Int
        let waitMs: Int
        let outcome: SingleFlightOutcome

        lock.lock()
        guard let e = inflight[key], !e.finished else {
            lock.unlock()
            return
        }
        e.finished = true
        inflight.removeValue(forKey: key)
        callbacks = Array(e.callbacks.values)
        waiters = callbacks.count
        waitMs = Int(((CFAbsoluteTimeGetCurrent() - e.startedAt) * 1000.0).rounded())
        let timer = e.timer
        lock.unlock()

        timer?.cancel()
        callbacks.forEach { $0(result) }

        switch result {
        case .success:
            outcome = .success
        case .failure(let err):
            if err is SingleFlightError, (err as? SingleFlightError) == .timeout {
                outcome = .timeout
            } else {
                outcome = .failure
            }
        }
        observer?.onFinish(key: key, waiters: waiters, waitMs: waitMs, outcome: outcome)
    }

    func clear() {
        lock.lock(); defer { lock.unlock() }
        inflight.values.forEach { $0.timer?.cancel() }
        inflight.removeAll()
    }
}

private enum SFKey {
    static func tokenRefresh(userId: String, authScope: String, env: String) -> String {
        "refresh:\(userId):\(authScope):\(env)"
    }

    static func me(userId: String, authScope: String, locale: String, appVersion: String) -> String {
        "me:\(userId):\(authScope):\(locale):\(appVersion)"
    }

    static func config(userIdOrAnon: String, deviceId: String, locale: String, region: String, appVersion: String, scene: String, env: String) -> String {
        "config:\(userIdOrAnon):\(deviceId):\(locale):\(region):\(appVersion):\(scene):\(env)"
    }

    static func item(resourceId: String, userIdOrAnon: String, locale: String, region: String, fieldsMask: String) -> String {
        "item:\(resourceId):\(userIdOrAnon):\(locale):\(region):\(fieldsMask)"
    }

    static func mediaMeta(mediaId: String, variant: String, userIdOrAnon: String, authScope: String, locale: String) -> String {
        "mediaMeta:\(mediaId):\(variant):\(userIdOrAnon):\(authScope):\(locale)"
    }

    static func cacheFill(logicalKey: String, userIdOrAnon: String, locale: String, region: String, appVersion: String) -> String {
        "cacheFill:\(logicalKey):\(userIdOrAnon):\(locale):\(region):\(appVersion)"
    }

    static func dbRead(table: String, primaryKey: String, projection: String) -> String {
        "dbRead:\(table):\(primaryKey):\(projection)"
    }
}

private final class TTLCache {
    private let lock = NSLock()
    private var map: [String: (String, Date)] = [:]

    func get(_ key: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        guard let v = map[key] else { return nil }
        if v.1 > Date() { return v.0 }
        map.removeValue(forKey: key)
        return nil
    }

    func set(_ key: String, value: String, ttlSeconds: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        map[key] = (value, Date().addingTimeInterval(ttlSeconds))
    }

    func expire(_ key: String) {
        lock.lock(); defer { lock.unlock() }
        map.removeValue(forKey: key)
    }

    func clear() {
        lock.lock(); defer { lock.unlock() }
        map.removeAll()
    }
}

private enum DemoError: Error {
    case forcedFailure
}

private final class FakeBackend {
    func call(path: String, delayMs: Int, completion: @escaping (Result<String, Error>) -> Void) {
        let d = DispatchTime.now() + .milliseconds(delayMs)
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: d) {
            completion(.success("\(path)@\(Int(Date().timeIntervalSince1970))"))
        }
    }

    func io(name: String, delayMs: Int, completion: @escaping (Result<String, Error>) -> Void) {
        let d = DispatchTime.now() + .milliseconds(delayMs)
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: d) {
            completion(.success("\(name)@\(Int(Date().timeIntervalSince1970))"))
        }
    }
}

private final class DemoRepository {
    var enableSingleFlight: Bool = true

    private let backend = FakeBackend()
    private let cache = TTLCache()
    private let sf = SingleFlight<String>()

    private let metrics = DemoMetrics()
    private lazy var observer: SingleFlightObserver = MetricsObserver(metrics: metrics)

    func snapshot() -> DemoMetricsSnapshot { metrics.snapshot() }

    func refreshToken(userId: String, authScope: String, completion: @escaping (Result<String, Error>) -> Void) {
        let key = SFKey.tokenRefresh(userId: userId, authScope: authScope, env: "prod")
        let start: (@escaping (Result<String, Error>) -> Void) -> Void = { done in
            self.backend.call(path: "POST /auth/refresh", delayMs: 320, completion: done)
        }
        run(key: key, start: start, completion: completion)
    }

    func fetchMe(userId: String, authScope: String, locale: String, completion: @escaping (Result<String, Error>) -> Void) {
        let key = SFKey.me(userId: userId, authScope: authScope, locale: locale, appVersion: appVersion)
        let start: (@escaping (Result<String, Error>) -> Void) -> Void = { done in
            self.backend.call(path: "GET /me", delayMs: 260, completion: done)
        }
        run(key: key, start: start, completion: completion)
    }

    func fetchConfig(userId: String?, anonId: String?, locale: String, region: String, scene: String, completion: @escaping (Result<String, Error>) -> Void) {
        let id = userId ?? anonId ?? "anon"
        let key = SFKey.config(userIdOrAnon: id, deviceId: deviceId, locale: locale, region: region, appVersion: appVersion, scene: scene, env: "prod")
        let start: (@escaping (Result<String, Error>) -> Void) -> Void = { done in
            self.backend.call(path: "GET /config?scene=\(scene)", delayMs: 220, completion: done)
        }
        run(key: key, start: start, completion: completion)
    }

    func fetchItemDetail(resourceId: String, userId: String?, locale: String, region: String, fieldsMask: String, completion: @escaping (Result<String, Error>) -> Void) {
        let id = userId ?? "anon"
        let key = SFKey.item(resourceId: resourceId, userIdOrAnon: id, locale: locale, region: region, fieldsMask: fieldsMask)
        let start: (@escaping (Result<String, Error>) -> Void) -> Void = { done in
            self.backend.call(path: "GET /item/\(resourceId)", delayMs: 280, completion: done)
        }
        run(key: key, start: start, completion: completion)
    }

    func fetchMediaMeta(mediaId: String, variant: String, userId: String?, authScope: String, locale: String, completion: @escaping (Result<String, Error>) -> Void) {
        let id = userId ?? "anon"
        let key = SFKey.mediaMeta(mediaId: mediaId, variant: variant, userIdOrAnon: id, authScope: authScope, locale: locale)
        let start: (@escaping (Result<String, Error>) -> Void) -> Void = { done in
            self.backend.call(path: "GET /media/\(mediaId)/meta?variant=\(variant)", delayMs: 240, completion: done)
        }
        run(key: key, start: start, completion: completion)
    }

    func getOrLoadCache(logicalKey: String, userId: String?, locale: String, region: String, ttlSeconds: TimeInterval, completion: @escaping (Result<String, Error>) -> Void) {
        if let v = cache.get(logicalKey) {
            completion(.success("cacheHit \(v)"))
            return
        }

        let id = userId ?? "anon"
        let key = SFKey.cacheFill(logicalKey: logicalKey, userIdOrAnon: id, locale: locale, region: region, appVersion: appVersion)
        let start: (@escaping (Result<String, Error>) -> Void) -> Void = { done in
            self.backend.call(path: "GET /feed?scene=home", delayMs: 360) { result in
                switch result {
                case .success(let v):
                    self.cache.set(logicalKey, value: v, ttlSeconds: ttlSeconds)
                    done(.success(v))
                case .failure(let e):
                    done(.failure(e))
                }
            }
        }
        run(key: key, start: start, completion: completion)
    }

    func expireCache(logicalKey: String) {
        cache.expire(logicalKey)
    }

    func dbRead(table: String, primaryKey: String, projection: String, completion: @escaping (Result<String, Error>) -> Void) {
        let key = SFKey.dbRead(table: table, primaryKey: primaryKey, projection: projection)
        let start: (@escaping (Result<String, Error>) -> Void) -> Void = { done in
            self.backend.io(name: "DB.fetch \(table)[\(primaryKey)]", delayMs: 180, completion: done)
        }
        run(key: key, start: start, completion: completion)
    }

    private func run(key: String, options: SingleFlightOptions = .default, start: (@escaping (Result<String, Error>) -> Void) -> Void, completion: @escaping (Result<String, Error>) -> Void) {
        if enableSingleFlight {
            _ = sf.run(key: key, options: options, start: start, completion: completion, observer: observer)
        } else {
            start(completion)
        }
    }

    private var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0"
    }

    private var deviceId: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }
}

