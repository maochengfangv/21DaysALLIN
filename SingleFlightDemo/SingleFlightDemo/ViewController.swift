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
            self.repo.fetchConfig(userId: "u1", anonId: nil as String?, locale: "zh-Hans", region: "CN", scene: "home", completion: done)
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
        let header = "sf=\(repo.enableSingleFlight) origin=\(m.origin) coalesced=\(m.coalesced) stale=\(m.stale) bypass=\(m.bypass) reject=\(m.rejected) timeout=\(m.timeout) inflightMax=\(m.inflightMax) ok=\(m.ok) fail=\(m.fail) waitP95=\(m.waitP95ms)ms waitP99=\(m.waitP99ms)ms"
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
    private(set) var stale: Int = 0
    private(set) var bypass: Int = 0
    private(set) var rejected: Int = 0
    private(set) var timeout: Int = 0
    private(set) var inflightMax: Int = 0
    private(set) var ok: Int = 0
    private(set) var fail: Int = 0
    private var waitSamplesMs: [Int] = []

    func onStart(inflight: Int) { lock.lock(); defer { lock.unlock() }; origin += 1; inflightMax = max(inflightMax, inflight) }
    func onJoin() { lock.lock(); defer { lock.unlock() }; coalesced += 1 }
    func onStale() { lock.lock(); defer { lock.unlock() }; stale += 1 }
    func onBypass() { lock.lock(); defer { lock.unlock() }; bypass += 1 }
    func onRejected() { lock.lock(); defer { lock.unlock() }; rejected += 1 }
    func onTimeout() { lock.lock(); defer { lock.unlock() }; timeout += 1 }
    func onFinish(_ event: SingleFlightEvent) {
        lock.lock(); defer { lock.unlock() }
        if event.ok { ok += 1 } else { fail += 1 }
        waitSamplesMs.append(event.waitMs)
        if waitSamplesMs.count > 400 { waitSamplesMs.removeFirst(waitSamplesMs.count - 400) }
    }
    func reset() { lock.lock(); defer { lock.unlock() }; origin = 0; coalesced = 0; stale = 0; bypass = 0; rejected = 0; timeout = 0; inflightMax = 0; ok = 0; fail = 0; waitSamplesMs.removeAll() }
    func snapshot() -> DemoMetricsSnapshot {
        lock.lock(); defer { lock.unlock() }
        return DemoMetricsSnapshot(origin: origin, coalesced: coalesced, stale: stale, bypass: bypass, rejected: rejected, timeout: timeout, inflightMax: inflightMax, ok: ok, fail: fail, waitP95ms: percentile(waitSamplesMs, 0.95), waitP99ms: percentile(waitSamplesMs, 0.99))
    }
    private func percentile(_ xs: [Int], _ p: Double) -> Int { guard !xs.isEmpty else { return 0 }; let s = xs.sorted(); return s[min(max(Int(Double(s.count - 1) * p), 0), s.count - 1)] }
}

private struct DemoMetricsSnapshot {
    let origin: Int
    let coalesced: Int
    let stale: Int
    let bypass: Int
    let rejected: Int
    let timeout: Int
    let inflightMax: Int
    let ok: Int
    let fail: Int
    let waitP95ms: Int
    let waitP99ms: Int
}

private protocol SingleFlightObserver: AnyObject {
    func onStart(key: String, inflight: Int)
    func onJoin(key: String)
    func onFinish(key: String, waiters: Int, waitMs: Int, result: Result<String, Error>)
    func onStale(key: String)
    func onBypass(key: String, reason: String)
    func onRejectJoin(key: String, maxWaiters: Int)
    func onTimeout(key: String)
}

private final class MetricsObserver: SingleFlightObserver {
    private let metrics: DemoMetrics
    init(metrics: DemoMetrics) { self.metrics = metrics }
    func onStart(key: String, inflight: Int) { metrics.onStart(inflight: inflight) }
    func onJoin(key: String) { metrics.onJoin() }
    func onStale(key: String) { metrics.onStale() }
    func onBypass(key: String, reason: String) { metrics.onBypass() }
    func onRejectJoin(key: String, maxWaiters: Int) { metrics.onRejected() }
    func onTimeout(key: String) { metrics.onTimeout() }
    func onFinish(key: String, waiters: Int, waitMs: Int, result: Result<String, Error>) {
        let ok: Bool
        switch result {
        case .success: ok = true
        case .failure: ok = false
        }
        metrics.onFinish(SingleFlightEvent(key: key, waiters: waiters, waitMs: waitMs, ok: ok))
    }
}

private enum RequestEffect: Equatable { case readOnly, idempotentSideEffect, nonMergeableSideEffect }
private enum FailureStrategy: Equatable { case broadcastSharedFailure, retryJoinersIndividually }

private struct SingleFlightPolicy {
    let effect: RequestEffect
    let timeoutMs: Int
    let maxWaiters: Int
    let failureStrategy: FailureStrategy
    let staleWhileRevalidate: Bool
}

private enum SingleFlightError: LocalizedError {
    case timedOut(String)
    case tooManyWaiters(String, Int)
    var errorDescription: String? {
        switch self {
        case .timedOut(let key): return "singleflight timeout: \(key)"
        case .tooManyWaiters(let key, let max): return "singleflight rejected: \(key), max=\(max)"
        }
    }
}

private final class SingleFlight<Value> {
    private struct Entry {
        let startedAt: CFAbsoluteTime
        let start: (@escaping (Result<Value, Error>) -> Void) -> Void
        let policy: SingleFlightPolicy
        var callbacks: [(Result<Value, Error>) -> Void]
        var timeoutWorkItem: DispatchWorkItem?
    }

    private let lock = NSLock()
    private var inflight: [String: Entry] = [:]

    func run(key: String, policy: SingleFlightPolicy, start: @escaping (@escaping (Result<Value, Error>) -> Void) -> Void, completion: @escaping (Result<Value, Error>) -> Void, observer: SingleFlightObserver? = nil) {
        if policy.effect == .nonMergeableSideEffect { observer?.onBypass(key: key, reason: "non-mergeable-side-effect"); start(completion); return }
        lock.lock()
        if var entry = inflight[key] {
            if entry.callbacks.count >= policy.maxWaiters {
                lock.unlock()
                observer?.onRejectJoin(key: key, maxWaiters: policy.maxWaiters)
                completion(.failure(SingleFlightError.tooManyWaiters(key, policy.maxWaiters)))
                return
            }
            entry.callbacks.append(completion)
            inflight[key] = entry
            lock.unlock()
            observer?.onJoin(key: key)
            return
        }
        inflight[key] = Entry(startedAt: CFAbsoluteTimeGetCurrent(), start: start, policy: policy, callbacks: [completion], timeoutWorkItem: nil)
        let inflightCount = inflight.count
        lock.unlock()
        observer?.onStart(key: key, inflight: inflightCount)
        installTimeoutIfNeeded(key: key, policy: policy, observer: observer)
        start { [weak self] result in self?.finish(key: key, result: result, observer: observer) }
    }

    func clear() { lock.lock(); defer { lock.unlock() }; inflight.values.forEach { $0.timeoutWorkItem?.cancel() }; inflight.removeAll() }

    private func installTimeoutIfNeeded(key: String, policy: SingleFlightPolicy, observer: SingleFlightObserver?) {
        guard policy.timeoutMs > 0 else { return }
        let item = DispatchWorkItem { [weak self] in self?.timeout(key: key, observer: observer) }
        lock.lock(); if var entry = inflight[key] { entry.timeoutWorkItem = item; inflight[key] = entry }; lock.unlock()
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + .milliseconds(policy.timeoutMs), execute: item)
    }

    private func timeout(key: String, observer: SingleFlightObserver?) {
        lock.lock(); let entry = inflight.removeValue(forKey: key); lock.unlock()
        guard let entry else { return }
        observer?.onTimeout(key: key)
        entry.callbacks.forEach { $0(.failure(SingleFlightError.timedOut(key))) }
    }

    private func finish(key: String, result: Result<Value, Error>, observer: SingleFlightObserver?) {
        lock.lock(); let entry = inflight.removeValue(forKey: key); lock.unlock()
        guard let entry else { return }
        entry.timeoutWorkItem?.cancel()
        let waitMs = Int(((CFAbsoluteTimeGetCurrent() - entry.startedAt) * 1000).rounded())
        switch result {
        case .failure where entry.policy.failureStrategy == .retryJoinersIndividually && entry.callbacks.count > 1:
            entry.callbacks.first?(result)
            entry.callbacks.dropFirst().forEach { cb in observer?.onBypass(key: key, reason: "retry-after-shared-failure"); entry.start(cb) }
        default:
            entry.callbacks.forEach { $0(result) }
        }
        let normalized: Result<String, Error>
        switch result {
        case .success: normalized = .success("ok")
        case .failure(let err): normalized = .failure(err)
        }
        observer?.onFinish(key: key, waiters: entry.callbacks.count, waitMs: waitMs, result: normalized)
    }
}

private enum SFKey {
    static func tokenRefresh(userId: String, authScope: String, appId: String, env: String, tokenFamily: String) -> String { "refresh:\(userId):\(authScope):\(appId):\(env):\(tokenFamily)" }
    static func me(userId: String, authScope: String, locale: String, appVersion: String, schemaVersion: String) -> String { "me:\(userId):\(authScope):\(locale):\(appVersion):\(schemaVersion)" }
    static func config(userIdOrAnon: String, deviceId: String, locale: String, region: String, appVersion: String, channel: String, experimentNamespace: String, env: String, bucketingId: String) -> String { "config:\(userIdOrAnon):\(deviceId):\(locale):\(region):\(appVersion):\(channel):\(experimentNamespace):\(env):\(bucketingId)" }
    static func item(resourceId: String, userIdOrAnon: String, locale: String, region: String, fieldsMask: String, appVersion: String) -> String { "item:\(resourceId):\(userIdOrAnon):\(locale):\(region):\(fieldsMask):\(appVersion)" }
    static func mediaMeta(mediaId: String, variant: String, cdnHost: String, locale: String, authScope: String, userIdOrAnon: String) -> String { "mediaMeta:\(mediaId):\(variant):\(cdnHost):\(locale):\(authScope):\(userIdOrAnon)" }
    static func cacheFill(logicalCacheKey: String, userIdOrAnon: String, locale: String, region: String, appVersion: String) -> String { "cacheFill:\(logicalCacheKey):\(userIdOrAnon):\(locale):\(region):\(appVersion)" }
    static func dbRead(table: String, primaryKey: String, projection: String, userId: String?) -> String {
        let normalizedUserId = userId ?? "anon"
        return "dbRead:\(table):\(primaryKey):\(projection):\(normalizedUserId)"
    }
}

private final class TTLCache {
    private let lock = NSLock()
    private var map: [String: (value: String, expireAt: Date)] = [:]

    func getFresh(_ key: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        guard let v = map[key] else { return nil }
        return v.expireAt > Date() ? v.value : nil
    }

    func getStale(_ key: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        return map[key]?.value
    }

    func set(_ key: String, value: String, ttlSeconds: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        map[key] = (value, Date().addingTimeInterval(ttlSeconds))
    }

    func expire(_ key: String, keepStale: Bool = true) {
        lock.lock(); defer { lock.unlock() }
        guard keepStale, let value = map[key]?.value else { map.removeValue(forKey: key); return }
        map[key] = (value, .distantPast)
    }

    func clear() { lock.lock(); defer { lock.unlock() }; map.removeAll() }
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

    private let refreshPolicy = SingleFlightPolicy(effect: .idempotentSideEffect, timeoutMs: 1500, maxWaiters: 12, failureStrategy: .broadcastSharedFailure, staleWhileRevalidate: false)
    private let profilePolicy = SingleFlightPolicy(effect: .readOnly, timeoutMs: 1200, maxWaiters: 24, failureStrategy: .broadcastSharedFailure, staleWhileRevalidate: false)
    private let configPolicy = SingleFlightPolicy(effect: .readOnly, timeoutMs: 1200, maxWaiters: 24, failureStrategy: .broadcastSharedFailure, staleWhileRevalidate: true)
    private let itemPolicy = SingleFlightPolicy(effect: .readOnly, timeoutMs: 1200, maxWaiters: 48, failureStrategy: .retryJoinersIndividually, staleWhileRevalidate: false)
    private let mediaPolicy = SingleFlightPolicy(effect: .readOnly, timeoutMs: 1000, maxWaiters: 48, failureStrategy: .broadcastSharedFailure, staleWhileRevalidate: false)
    private let cachePolicy = SingleFlightPolicy(effect: .readOnly, timeoutMs: 1200, maxWaiters: 48, failureStrategy: .broadcastSharedFailure, staleWhileRevalidate: true)
    private let dbPolicy = SingleFlightPolicy(effect: .readOnly, timeoutMs: 900, maxWaiters: 16, failureStrategy: .retryJoinersIndividually, staleWhileRevalidate: false)

    func snapshot() -> DemoMetricsSnapshot { metrics.snapshot() }
    func reset() { metrics.reset(); cache.clear(); sf.clear() }

    private func run(key: String, policy: SingleFlightPolicy, start: @escaping (@escaping (Result<String, Error>) -> Void) -> Void, completion: @escaping (Result<String, Error>) -> Void) {
        if enableSingleFlight { sf.run(key: key, policy: policy, start: start, completion: completion, observer: observer) }
        else { observer.onBypass(key: key, reason: "singleflight-disabled"); start(completion) }
    }

    private func revalidate(key: String, policy: SingleFlightPolicy, start: @escaping (@escaping (Result<String, Error>) -> Void) -> Void) {
        run(key: key, policy: policy, start: start) { _ in }
    }

    private func serveFreshOrStale(cacheKey: String, key: String, policy: SingleFlightPolicy, start: @escaping (@escaping (Result<String, Error>) -> Void) -> Void, completion: @escaping (Result<String, Error>) -> Void) {
        if let fresh = cache.getFresh(cacheKey) { completion(.success("fresh \(fresh)")); return }
        if policy.staleWhileRevalidate, let stale = cache.getStale(cacheKey) {
            observer.onStale(key: key)
            completion(.success("stale \(stale)"))
            revalidate(key: key, policy: policy, start: start)
            return
        }
        run(key: key, policy: policy, start: start, completion: completion)
    }

    private func canonicalQuery(_ query: [String: String]) -> String {
        query.keys.sorted().map { key in
            let value = query[key] ?? ""
            return "\(key)=\(value)"
        }.joined(separator: "&")
    }

    func refreshToken(userId: String, authScope: String, completion: @escaping (Result<String, Error>) -> Void) {
        let key = SFKey.tokenRefresh(userId: userId, authScope: authScope, appId: appId, env: env, tokenFamily: "session")
        let start: (@escaping (Result<String, Error>) -> Void) -> Void = { done in self.backend.call(path: "POST /auth/refresh", delayMs: 320, completion: done) }
        run(key: key, policy: refreshPolicy, start: start, completion: completion)
    }

    func fetchMe(userId: String, authScope: String, locale: String, completion: @escaping (Result<String, Error>) -> Void) {
        let key = SFKey.me(userId: userId, authScope: authScope, locale: locale, appVersion: appVersion, schemaVersion: schemaVersion)
        let start: (@escaping (Result<String, Error>) -> Void) -> Void = { done in self.backend.call(path: "GET /me", delayMs: 260, completion: done) }
        run(key: key, policy: profilePolicy, start: start, completion: completion)
    }

    func fetchConfig(userId: String?, anonId: String?, locale: String, region: String, scene: String, completion: @escaping (Result<String, Error>) -> Void) {
        let id = userId ?? anonId ?? "anon"
        let key = SFKey.config(userIdOrAnon: id, deviceId: deviceId, locale: locale, region: region, appVersion: appVersion, channel: channel, experimentNamespace: scene, env: env, bucketingId: id)
        let cacheKey = "config:\(id):\(scene)"
        let query = canonicalQuery(["scene": scene])
        let start: (@escaping (Result<String, Error>) -> Void) -> Void = { done in
            self.backend.call(path: "GET /config?\(query)", delayMs: 220) { result in
                if case .success(let v) = result { self.cache.set(cacheKey, value: v, ttlSeconds: 12) }
                done(result)
            }
        }
        serveFreshOrStale(cacheKey: cacheKey, key: key, policy: configPolicy, start: start, completion: completion)
    }

    func fetchItemDetail(resourceId: String, userId: String?, locale: String, region: String, fieldsMask: String, completion: @escaping (Result<String, Error>) -> Void) {
        let id = userId ?? "anon"
        let key = SFKey.item(resourceId: resourceId, userIdOrAnon: id, locale: locale, region: region, fieldsMask: fieldsMask, appVersion: appVersion)
        let query = canonicalQuery(["fields": fieldsMask])
        let path = "GET /item/\(resourceId)?\(query)"
        let start: (@escaping (Result<String, Error>) -> Void) -> Void = { done in self.backend.call(path: path, delayMs: 280, completion: done) }
        run(key: key, policy: itemPolicy, start: start, completion: completion)
    }

    func fetchMediaMeta(mediaId: String, variant: String, userId: String?, authScope: String, locale: String, completion: @escaping (Result<String, Error>) -> Void) {
        let id = userId ?? "anon"
        let key = SFKey.mediaMeta(mediaId: mediaId, variant: variant, cdnHost: cdnHost, locale: locale, authScope: authScope, userIdOrAnon: id)
        let query = canonicalQuery(["variant": variant])
        let path = "GET /media/\(mediaId)/meta?\(query)"
        let start: (@escaping (Result<String, Error>) -> Void) -> Void = { done in self.backend.call(path: path, delayMs: 240, completion: done) }
        run(key: key, policy: mediaPolicy, start: start, completion: completion)
    }

    func getOrLoadCache(logicalKey: String, userId: String?, locale: String, region: String, ttlSeconds: TimeInterval, completion: @escaping (Result<String, Error>) -> Void) {
        let normalizedKey = "feed:\(locale):\(region):\(logicalKey)"
        let id = userId ?? "anon"
        let key = SFKey.cacheFill(logicalCacheKey: normalizedKey, userIdOrAnon: id, locale: locale, region: region, appVersion: appVersion)
        let query = canonicalQuery(["scene": "home"])
        let path = "GET /feed?\(query)"
        let start: (@escaping (Result<String, Error>) -> Void) -> Void = { done in
            self.backend.call(path: path, delayMs: 360) { result in
                if case .success(let v) = result { self.cache.set(normalizedKey, value: v, ttlSeconds: ttlSeconds) }
                done(result)
            }
        }
        serveFreshOrStale(cacheKey: normalizedKey, key: key, policy: cachePolicy, start: start, completion: completion)
    }

    func expireCache(logicalKey: String) { cache.expire("feed:zh-Hans:CN:\(logicalKey)") }

    func dbRead(table: String, primaryKey: String, projection: String, completion: @escaping (Result<String, Error>) -> Void) {
        let key = SFKey.dbRead(table: table, primaryKey: primaryKey, projection: projection, userId: "u1")
        let start: (@escaping (Result<String, Error>) -> Void) -> Void = { done in self.backend.io(name: "DB.fetch \(table)[\(primaryKey)] fields=\(projection)", delayMs: 180, completion: done) }
        run(key: key, policy: dbPolicy, start: start, completion: completion)
    }

    private var appId: String { Bundle.main.bundleIdentifier ?? "singleflight.demo" }
    private var appVersion: String { (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0" }
    private var schemaVersion: String { "v1" }
    private var channel: String { "appstore" }
    private var env: String { "prod" }
    private var cdnHost: String { "img.demo.local" }
    private var deviceId: String { UIDevice.current.identifierForVendor?.uuidString ?? "unknown" }
}

