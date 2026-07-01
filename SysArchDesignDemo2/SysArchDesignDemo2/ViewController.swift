//
//  ViewController.swift
//  SysArchDesignDemo2
//
//  Created by maochengfang on 2026/6/30.
//

import UIKit
import Foundation

final class ViewController: UIViewController {
    private let cfg = UILabel()
    private let stat = UILabel()
    private let log = UITextView()

    private let timeout = UISwitch()
    private let singleFlight = UISwitch()

    private let env = DemoEnv()
    private var logs: [String] = []
    private var reqSeq = 0

    private let key = "item_42"
    private let ttl: TimeInterval = 4
    private let burst = 8

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Decoupled Demo"
        view.backgroundColor = .systemBackground
        timeout.isOn = env.injectTimeout
        singleFlight.isOn = env.enableSingleFlight
        buildUI()
        render("ready")
    }

    func buildUI() {
        cfg.numberOfLines = 0
        cfg.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        stat.numberOfLines = 0
        stat.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        log.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        log.isEditable = false
        log.backgroundColor = .secondarySystemBackground
        log.layer.cornerRadius = 10
        timeout.addTarget(self, action: #selector(onTimeout), for: .valueChanged)
        singleFlight.addTarget(self, action: #selector(onSingleFlight), for: .valueChanged)

        let row1 = UIStackView(arrangedSubviews: [btn("Warm Cache", #selector(onWarm)), btn("Expire Cache", #selector(onExpire))])
        let row2 = UIStackView(arrangedSubviews: [btn("Fetch Once", #selector(onFetch)), btn("Burst x8", #selector(onBurst))])
        [row1, row2].forEach { $0.axis = .horizontal; $0.spacing = 12; $0.distribution = .fillEqually }

        let t1 = UILabel(); t1.text = "超时注入"; t1.font = .systemFont(ofSize: 15, weight: .medium)
        let t2 = UILabel(); t2.text = "SingleFlight"; t2.font = .systemFont(ofSize: 15, weight: .medium)
        let toggle = UIStackView(arrangedSubviews: [t1, timeout, t2, singleFlight]); toggle.axis = .horizontal; toggle.spacing = 12; toggle.alignment = .center

        let stack = UIStackView(arrangedSubviews: [titleLabel(), cfg, stat, toggle, row1, row2, log])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            log.heightAnchor.constraint(equalToConstant: 260)
        ])
    }

    func titleLabel() -> UILabel {
        let v = UILabel()
        v.numberOfLines = 0
        v.text = "高耦合原始 Demo：页面、网络、缓存逻辑全部堆在控制器"
        v.font = .systemFont(ofSize: 20, weight: .semibold)
        return v
    }

    func btn(_ title: String, _ action: Selector) -> UIButton {
        let v = UIButton(type: .system)
        v.setTitle(title, for: .normal)
        v.addTarget(self, action: action, for: .touchUpInside)
        return v
    }

    @objc func onTimeout() { env.injectTimeout = timeout.isOn; render("timeout inject = \(timeout.isOn)") }
    @objc func onSingleFlight() { env.enableSingleFlight = singleFlight.isOn; render("singleflight = \(singleFlight.isOn)") }
    @objc func onWarm() { env.warm(key: key, ttl: ttl); render("cache warmed") }
    @objc func onExpire() { env.expire(key: key); render("cache expired") }
    @objc func onFetch() { fetch(tag: "single") }
    @objc func onBurst() { (0..<burst).forEach { fetch(tag: "burst-\($0)") } }

    func fetch(tag: String) {
        reqSeq += 1
        let req = reqSeq

        env.fetch(key: key, ttl: ttl) { [weak self] result in
            guard let self else { return }
            DispatchQueue.main.async {
                switch result {
                case .success(let v):
                    self.render("#\(req) \(tag) -> \(v)")
                case .failure:
                    self.render("#\(req) \(tag) timeout -> fallback")
                }
            }
        }
    }

    func render(_ line: String) {
        let m = env.snapshot()
        cfg.text = "key=\(key) ttl=\(Int(ttl))s burst=\(burst) singleflight=\(env.enableSingleFlight)"
        stat.text = "hit=\(m.hit) miss=\(m.miss) origin=\(m.origin) timeout=\(m.timeout) cache=\(env.cacheState(key: key))"
        logs.append(line)
        if logs.count > 14 { logs.removeFirst(logs.count - 14) }
        log.text = logs.joined(separator: "\n")
    }
}

private struct DemoMetrics {
    var hit = 0
    var miss = 0
    var origin = 0
    var timeout = 0

    mutating func reset() {
        hit = 0
        miss = 0
        origin = 0
        timeout = 0
    }
}

private final class TTLCache {
    private let lock = NSLock()
    private var map: [String: (Data, Date)] = [:]

    func get(_ key: String) -> Data? {
        lock.lock(); defer { lock.unlock() }
        guard let v = map[key] else { return nil }
        if v.1 > Date() { return v.0 }
        map.removeValue(forKey: key)
        return nil
    }

    func set(_ key: String, data: Data, ttl: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        map[key] = (data, Date().addingTimeInterval(ttl))
    }

    func expire(_ key: String) {
        lock.lock(); defer { lock.unlock() }
        map.removeValue(forKey: key)
    }

    func hasValid(_ key: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard let v = map[key] else { return false }
        if v.1 > Date() { return true }
        map.removeValue(forKey: key)
        return false
    }

    func clear() {
        lock.lock(); defer { lock.unlock() }
        map.removeAll()
    }
}

private final class SingleFlight {
    private let lock = NSLock()
    private var inflight: [String: [(Result<Data, Error>) -> Void]] = [:]

    func run(key: String, start: (@escaping (Result<Data, Error>) -> Void) -> Void, completion: @escaping (Result<Data, Error>) -> Void) {
        // SingleFlight（并发合并）的目标：
        // - 同一个 key 在同一时间窗口内可能被多个并发请求触发。
        // - 这些请求本质上在等待“同一个回源结果”。
        // - 因此只让第一个请求真正回源，其余请求不再发起网络/IO，而是挂起等待复用结果。
        //
        // inflight 的含义：
        // - inflight[key] 存在：表示“该 key 当前已经有一个回源正在进行”。
        // - inflight[key] 的数组：存放所有等待该 key 回源结果的 completion 回调。

        // 需要加锁：inflight 是共享可变状态，会被多个线程同时读写（并发请求）。
        lock.lock()

        if inflight[key] != nil {
            // 非首个请求（已经有人在回源）：
            // - 只把自己的 completion 追加到等待队列
            // - 直接返回，不触发 start（不回源）
            inflight[key]?.append(completion)
            lock.unlock()
            return
        }

        // 首个请求：
        // - 创建该 key 的等待队列，并把自己也放进去
        // - 然后释放锁，继续执行真正的回源逻辑
        inflight[key] = [completion]
        lock.unlock()

        // 真正的回源开始：start 由调用方提供（可能是网络请求/磁盘 IO 等）。
        // start 的回调只会被调用一次，返回本次回源的最终结果（成功或失败）。
        start { [weak self] result in
            // 注意：这里用 weak self 是为了避免循环引用。
            // 在生产代码里通常要确保 SingleFlight 的生命周期覆盖 inflight 请求，
            // 否则 self 被释放会导致等待者永远收不到回调。
            guard let self else { return }

            // 回源结束：
            // - 必须原子地取出并清理 inflight[key]，避免后续请求继续挂在旧队列上。
            self.lock.lock()
            let callbacks = self.inflight.removeValue(forKey: key) ?? []
            self.lock.unlock()

            // 广播结果：
            // - 对所有等待者回调同一个 result
            // - 执行线程取决于 start 回调所在的队列（SingleFlight 本身不切线程）
            callbacks.forEach { $0(result) }
        }
    }

    func clear() {
        lock.lock(); defer { lock.unlock() }
        inflight.removeAll()
    }
}

private protocol Transport {
    func send(_ request: URLRequest, completion: @escaping (Result<Data, Error>) -> Void)
}

private final class FakeTransport: Transport {
    private let lock = NSLock()
    private var seq: Int = 0

    func send(_ request: URLRequest, completion: @escaping (Result<Data, Error>) -> Void) {
        lock.lock(); seq += 1; let id = seq; lock.unlock()
        let delay: TimeInterval = 0.25
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + delay) {
            let body = "{\"id\":\(id),\"ts\":\(Int(Date().timeIntervalSince1970))}"
            completion(.success(Data(body.utf8)))
        }
    }
}

private protocol AsyncInterceptor {
    func intercept(_ request: URLRequest, next: @escaping (URLRequest, @escaping (Result<Data, Error>) -> Void) -> Void, completion: @escaping (Result<Data, Error>) -> Void)
}

private final class TimeoutInjector: AsyncInterceptor {
    var enabled = false
    var timeoutSeconds: TimeInterval = 1.2

    private let lock = NSLock()
    private var seq = 0

    func reset() {
        lock.lock(); defer { lock.unlock() }
        seq = 0
    }

    func intercept(_ request: URLRequest, next: @escaping (URLRequest, @escaping (Result<Data, Error>) -> Void) -> Void, completion: @escaping (Result<Data, Error>) -> Void) {
        lock.lock(); seq += 1; let id = seq; lock.unlock()
        if enabled && id % 3 == 0 {
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + timeoutSeconds) {
                completion(.failure(URLError(.timedOut)))
            }
            return
        }
        next(request, completion)
    }
}

private final class NetworkClient {
    private let transport: Transport
    private let interceptors: [AsyncInterceptor]

    init(transport: Transport, interceptors: [AsyncInterceptor]) {
        self.transport = transport
        self.interceptors = interceptors
    }

    func send(_ request: URLRequest, completion: @escaping (Result<Data, Error>) -> Void) {
        func sender(_ index: Int, _ req: URLRequest, _ done: @escaping (Result<Data, Error>) -> Void) {
            if index >= interceptors.count {
                transport.send(req, completion: done)
                return
            }
            interceptors[index].intercept(req, next: { r, cb in sender(index + 1, r, cb) }, completion: done)
        }
        sender(0, request, completion)
    }
}

private final class DemoEnv {
    var injectTimeout: Bool { didSet { timeoutInjector.enabled = injectTimeout } }
    var enableSingleFlight: Bool

    private let cache = TTLCache()
    private let singleFlight = SingleFlight()
    private var metrics = DemoMetrics()

    private let timeoutInjector = TimeoutInjector()
    private let client: NetworkClient

    init(injectTimeout: Bool = false, enableSingleFlight: Bool = false) {
        self.injectTimeout = injectTimeout
        self.enableSingleFlight = enableSingleFlight
        client = NetworkClient(transport: FakeTransport(), interceptors: [timeoutInjector])
        timeoutInjector.enabled = injectTimeout
    }

    func reset() {
        cache.clear()
        singleFlight.clear()
        metrics.reset()
        timeoutInjector.reset()
    }

    func snapshot() -> DemoMetrics { metrics }

    func cacheState(key: String) -> String {
        cache.hasValid(key) ? "valid" : "empty"
    }

    func warm(key: String, ttl: TimeInterval) {
        let body = "{\"warm\":true,\"ts\":\(Int(Date().timeIntervalSince1970))}"
        cache.set(key, data: Data(body.utf8), ttl: ttl)
    }

    func expire(key: String) {
        cache.expire(key)
    }

    func fetch(key: String, ttl: TimeInterval, completion: @escaping (Result<String, Error>) -> Void) {
        if let data = cache.get(key) {
            metrics.hit += 1
            completion(.success(String(data: data, encoding: .utf8) ?? "<binary>"))
            return
        }
        metrics.miss += 1

        let url = URL(string: "https://example.local/api/item?id=42")!
        let req = URLRequest(url: url)

        let start: (@escaping (Result<Data, Error>) -> Void) -> Void = { done in
            self.metrics.origin += 1
            self.client.send(req, completion: done)
        }

        let finish: (Result<Data, Error>) -> Void = { result in
            switch result {
            case .success(let data):
                self.cache.set(key, data: data, ttl: ttl)
                completion(.success(String(data: data, encoding: .utf8) ?? "<binary>"))
            case .failure(let err):
                if (err as? URLError)?.code == .timedOut { self.metrics.timeout += 1 }
                completion(.failure(err))
            }
        }

        if enableSingleFlight {
            singleFlight.run(key: key, start: start, completion: finish)
        } else {
            start(finish)
        }
    }
}

