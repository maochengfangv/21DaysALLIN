//
//  ViewController.swift
//  FlutterContainerDemo
//
//  Created by maochengfang on 2026/7/1.
//

import UIKit
import Flutter

class ViewController: UIViewController {
    private let resultLabel = UILabel()
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "iOS Container (V2 Router)"
        view.backgroundColor = .systemBackground

        let openChannelButton = makeButton(title: "① AppRouter.open → channel_demos", action: #selector(openChannelDemosTapped))
        let openCounterButton = makeButton(title: "② pushForResult → counter_demo", action: #selector(openCounterTapped))
        let openNativeButton = makeButton(title: "③ AppRouter.open → native_page", action: #selector(openNativePageTapped))
        let openDeeplinkButton = makeButton(title: "④ Deeplink → /platform_view", action: #selector(openDeeplinkTapped))
        let openNeedLoginButton = makeButton(title: "⑤ 需登录路由 user_profile", action: #selector(openNeedLoginTapped))
        let openBadRouteButton = makeButton(title: "⑥ 路由不存在（异常兜底）", action: #selector(openBadRouteTapped))
        let loggerSnapshotButton = makeButton(title: "📊 RouteLogger Snapshot", action: #selector(showLoggerSnapshot))

        resultLabel.textAlignment = .center
        resultLabel.numberOfLines = 0
        resultLabel.textColor = .secondaryLabel
        resultLabel.text = "Result: (none)"

        statusLabel.textAlignment = .left
        statusLabel.numberOfLines = 0
        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = .tertiaryLabel
        statusLabel.text = """
        ✅ V2 路由架构已启用
        • AppRouter 统一入口 + RouteRegistry 元信息注册
        • ContainerDispatcher 分发 Native/Flutter
        • BackDispatcher 统一返回分流（按钮/侧滑）
        • RouteLogger 埋点 + 异常兜底页
        """

        let stack = UIStackView(arrangedSubviews: [
            openChannelButton,
            openCounterButton,
            openNativeButton,
            openDeeplinkButton,
            openNeedLoginButton,
            openBadRouteButton,
            loggerSnapshotButton,
            resultLabel,
            statusLabel
        ])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.addSubview(stack)

        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            resultLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    private func makeButton(title: String, action: Selector) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.titlePadding = 10
        config.buttonSize = .medium
        config.cornerStyle = .medium
        config.baseBackgroundColor = .systemBlue.withAlphaComponent(0.92)
        let button = UIButton(configuration: config, primaryAction: nil)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    // MARK: - 示例 1：AppRouter.open 基础跳转

    @objc private func openChannelDemosTapped() {
        AppRouter.shared.open(
            routeName: "channel_demos",
            params: ["from": "ios_home", "timestamp": Int(Date().timeIntervalSince1970)],
            sourcePage: "native_home",
            from: self
        ) { [weak self] result in
            self?.updateResultLabel(result: result)
        }
    }

    // MARK: - 示例 2：pushForResult 回传结果

    @objc private func openCounterTapped() {
        let reqId = AppRouter.shared.pushForResult(
            routeName: "counter_demo",
            params: ["initialCount": 10, "from": "ios_pushForResult"],
            sourcePage: "native_home",
            from: self
        ) { [weak self] result in
            self?.updateResultLabel(result: result, tag: "pushForResult")
        }
        resultLabel.text = "→ pushForResult 已发起，requestId=\(reqId ?? "-")"
    }

    // MARK: - 示例 3：跳转到 Native Page（容器路由无感知）

    @objc private func openNativePageTapped() {
        AppRouter.shared.open(
            routeName: "native_page",
            params: ["openedBy": "AppRouter", "value": 42, "nested": ["a": 1, "b": "x"]],
            sourcePage: "native_home",
            from: self
        ) { [weak self] result in
            self?.updateResultLabel(result: result, tag: "native_page")
        }
    }

    // MARK: - 示例 4：Deeplink 输入 → RouteRequest 统一对象

    @objc private func openDeeplinkTapped() {
        guard let url = URL(string: "maocfdemo://platform_view?color=%23FF4D96FF&text=From%20Deeplink") else { return }
        AppRouter.shared.open(
            deeplink: url,
            source: .deeplink,
            from: self
        ) { [weak self] result in
            self?.updateResultLabel(result: result, tag: "deeplink")
        }
    }

    // MARK: - 示例 5：未登录路由 → 登录兜底 + 恢复

    @objc private func openNeedLoginTapped() {
        UserSession.shared.isLoggedIn = false
        AppRouter.shared.open(
            routeName: "user_profile",
            params: ["userId": "user_10086"],
            sourcePage: "native_home",
            from: self
        ) { [weak self] result in
            self?.updateResultLabel(result: result, tag: "need_login")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            UserSession.shared.isLoggedIn = true
            self?.resultLabel.text = "ℹ️ 模拟登录成功（UserSession.isLoggedIn = true）"
        }
    }

    // MARK: - 示例 6：异常路由 → route_error 兜底页

    @objc private func openBadRouteTapped() {
        AppRouter.shared.open(
            routeName: "route_not_exist_xyz",
            params: ["foo": "bar"],
            sourcePage: "native_home",
            from: self
        ) { [weak self] result in
            self?.updateResultLabel(result: result, tag: "bad_route")
        }
    }

    // MARK: - RouteLogger 统计面板

    @objc private func showLoggerSnapshot() {
        let snap = RouteLogger.shared.snapshot()
        let pretty = (snap as NSDictionary).description
        resultLabel.text = "📊 路由统计快照：\n\(pretty)"
    }

    // MARK: - 结果展示

    private func updateResultLabel(result: RouteResult, tag: String = "") {
        var payloadStr = ""
        if let dict = result.payload as? [String: Any] {
            payloadStr = (dict as NSDictionary).description
        } else if let v = result.payload {
            payloadStr = String(describing: v)
        } else {
            payloadStr = "(nil)"
        }
        let prefix = tag.isEmpty ? "" : "[\(tag)] "
        resultLabel.text = """
        \(prefix)Result ↓
        requestId: \(result.requestId)
        routeName: \(result.routeName)
        cancelled: \(result.isCancelled)
        payload: \(payloadStr)
        """
    }
}
