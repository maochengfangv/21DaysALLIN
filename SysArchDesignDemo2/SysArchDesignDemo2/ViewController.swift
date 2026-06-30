//
//  ViewController.swift
//  SysArchDesignDemo2
//
//  Created by maochengfang on 2026/6/30.
//

import UIKit

final class ViewController: UIViewController {
    let cfg = UILabel(), stat = UILabel(), log = UITextView(), timeout = UISwitch()
    var cache: [String: (String, Date)] = [:], logs: [String] = []
    var hit = 0, miss = 0, origin = 0, timeoutCount = 0, seq = 0
    let key = "item_42", ttl: TimeInterval = 4, burst = 8

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "High Coupling Demo"
        view.backgroundColor = .systemBackground
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

        let row1 = UIStackView(arrangedSubviews: [btn("Warm Cache", #selector(onWarm)), btn("Expire Cache", #selector(onExpire))])
        let row2 = UIStackView(arrangedSubviews: [btn("Fetch Once", #selector(onFetch)), btn("Burst x8", #selector(onBurst))])
        [row1, row2].forEach { $0.axis = .horizontal; $0.spacing = 12; $0.distribution = .fillEqually }

        let t = UILabel(); t.text = "超时注入"; t.font = .systemFont(ofSize: 15, weight: .medium)
        let toggle = UIStackView(arrangedSubviews: [t, timeout]); toggle.axis = .horizontal; toggle.spacing = 12; toggle.alignment = .center

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

    @objc func onTimeout() { render("timeout inject = \(timeout.isOn)") }
    @objc func onWarm() { cache[key] = (payload("warm"), Date().addingTimeInterval(ttl)); render("cache warmed") }
    @objc func onExpire() { cache.removeValue(forKey: key); render("cache expired") }
    @objc func onFetch() { fetch(tag: "single") }
    @objc func onBurst() { (0..<burst).forEach { fetch(tag: "burst-\($0)") } }

    func fetch(tag: String) {
        seq += 1
        let req = seq
        if let v = readCache() {
            hit += 1
            render("#\(req) \(tag) cache hit -> \(v)")
            return
        }
        miss += 1
        fakeNetwork(req: req, tag: tag) { [weak self] result in
            guard let self else { return }
            DispatchQueue.main.async {
                switch result {
                case .success(let v):
                    self.cache[self.key] = (v, Date().addingTimeInterval(self.ttl))
                    self.render("#\(req) \(tag) origin success -> \(v)")
                case .failure:
                    self.timeoutCount += 1
                    self.render("#\(req) \(tag) timeout -> fallback")
                }
            }
        }
    }

    func readCache() -> String? {
        guard let item = cache[key] else { return nil }
        if item.1 > Date() { return item.0 }
        cache.removeValue(forKey: key)
        return nil
    }

    func fakeNetwork(req: Int, tag: String, done: @escaping (Result<String, Error>) -> Void) {
        origin += 1
        let delay = timeout.isOn && req % 3 == 0 ? 1.4 : 0.35
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
            if delay > 1.0 { done(.failure(URLError(.timedOut))) }
            else { done(.success(self.payload(tag))) }
        }
    }

    func payload(_ from: String) -> String { "data_\(from)_t\(Int(Date().timeIntervalSince1970))" }

    func render(_ line: String) {
        cfg.text = "key=\(key) ttl=\(Int(ttl))s burst=\(burst) no-singleflight=true"
        stat.text = "hit=\(hit) miss=\(miss) origin=\(origin) timeout=\(timeoutCount) cache=\(cache[key] == nil ? "empty" : "valid")"
        logs.append(line)
        if logs.count > 14 { logs.removeFirst(logs.count - 14) }
        log.text = logs.joined(separator: "\n")
    }
}

