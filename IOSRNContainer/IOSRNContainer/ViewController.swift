import UIKit

final class ViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    private let openRNButton = makeCardButton(
        title: "打开 RN 主页面",
        subtitle: "MyRNModule · 完整 Demo 入口",
        color: UIColor(red: 0, green: 0.48, blue: 1, alpha: 1),
        icon: "📱"
    )

    private let openCardListButton = makeCardButton(
        title: "打开 RN 卡片列表",
        subtitle: "BusinessCardList · 独立模块入口",
        color: UIColor(red: 0.31, green: 0.27, blue: 0.9, alpha: 1),
        icon: "🎴"
    )

    private let switchEmbeddedButton = makeCardButton(
        title: "切换内置 Bundle",
        subtitle: "embedded · 使用 App 内置 JS 包",
        color: UIColor(red: 0.53, green: 0.12, blue: 0.89, alpha: 1),
        icon: "📦"
    )

    private let switchHotButton = makeCardButton(
        title: "切换热更 Bundle",
        subtitle: "hotUpdate · 使用已下载 JS 包",
        color: UIColor(red: 0.15, green: 0.68, blue: 0.38, alpha: 1),
        icon: "🔥"
    )

    private let reloadBundleButton = makeCardButton(
        title: "重新加载 Bundle",
        subtitle: "触发 RN Runtime 重载",
        color: UIColor(red: 0.95, green: 0.61, blue: 0.07, alpha: 1),
        icon: "🔄"
    )

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        label.textColor = UIColor(red: 0.29, green: 0.33, blue: 0.39, alpha: 1)
        label.backgroundColor = UIColor(red: 0.95, green: 0.96, blue: 0.97, alpha: 1)
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        label.textAlignment = .left
        label.isUserInteractionEnabled = true
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "RN 容器控制台"
        setupLayout()
        setupActions()
        refreshStatus()
    }

    private func setupLayout() {
        let padding: CGFloat = 16

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        scrollView.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: padding),
            stackView.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: padding),
            stackView.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -padding),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -padding * 2),

            statusLabel.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: padding),
            statusLabel.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -padding),
            statusLabel.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -padding),
        ])

        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.distribution = .fillEqually
        [openRNButton, openCardListButton, switchEmbeddedButton, switchHotButton, reloadBundleButton].forEach {
            stackView.addArrangedSubview($0)
        }
    }

    private func setupActions() {
        openRNButton.addTarget(self, action: #selector(openRNPage), for: .touchUpInside)
        openCardListButton.addTarget(self, action: #selector(openCardListPage), for: .touchUpInside)
        switchEmbeddedButton.addTarget(self, action: #selector(switchEmbedded), for: .touchUpInside)
        switchHotButton.addTarget(self, action: #selector(switchHotUpdate), for: .touchUpInside)
        reloadBundleButton.addTarget(self, action: #selector(reloadBundle), for: .touchUpInside)
    }

    private func refreshStatus() {
        var lines: [String] = []
        lines.append("=== Bundle & Bridge 状态 ===")

        let bundleExists = Bundle.main.url(forResource: "main", withExtension: "jsbundle") != nil
        lines.append("内置 main.jsbundle: \(bundleExists ? "✅" : "⚠️ 不存在（Debug 从 Metro 加载）")")

        #if canImport(RNBridgePodspec)
        let desc = RNBridgeManager.shared.currentBundleDescription()
        if let data = desc.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let source = dict["source"] as? Int ?? -1
            let sourceStr = source == 0 ? "embedded" : (source == 1 ? "hotUpdate" : "remoteDebug")
            let path = (dict["path"] as? String) ?? "nil"
            lines.append("当前源: \(sourceStr)")
            lines.append("路径: \(path)")
            lines.append("bridgeReady: \(dict["bridgeReady"] ?? false)")
            lines.append("bridgeValid: \(dict["bridgeValid"] ?? false)")
        }
        #else
        lines.append("当前源: Factory (未启用 RNBridgePodspec)")
        #endif

        statusLabel.text = "\n" + lines.joined(separator: "\n") + "\n"
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.refreshStatus()
        })
        present(alert, animated: true)
    }

    @objc
    private func openRNPage() {
        let reactNativeViewController = ReactNativeViewController(
            moduleName: "MyRNModule",
            initialProperties: [
                "fromNative": true,
                "entry": "IOSRNContainer",
                "title": "RN 主页面" as Any
            ]
        )
        let navigationController = UINavigationController(rootViewController: reactNativeViewController)
        navigationController.modalPresentationStyle = .fullScreen
        present(navigationController, animated: true)
    }

    @objc
    private func openCardListPage() {
        let mockCards: [[String: Any]] = [
            [
                "data": [
                    "cardId": "native-card-001",
                    "cardType": 0,
                    "title": "原生注入的卡片：Swift Concurrency 结构化并发",
                    "subtitle": "从 ViewController 传入 initialCards",
                    "description": "该卡片数据完全由 Native 侧构建，通过 TurboModule 回传初始数据，或通过 initialProperties 传递。",
                    "coverUrl": "https://images.unsplash.com/photo-1517694712202-14dd9538aa97?w=800&auto=format&fit=crop",
                    "author": "原生控制台",
                    "tag": "原生注入",
                    "timestamp": Date().timeIntervalSince1970 * 1000
                ],
                "actions": [
                    ["id": "a1", "title": "进入详情", "actionType": 0],
                    ["id": "a2", "title": "收藏", "actionType": 1]
                ]
            ],
            [
                "data": [
                    "cardId": "native-card-002",
                    "cardType": 1,
                    "title": "Fabric 原生渲染卡片（iOS 0 号卡片走原生）",
                    "subtitle": "JS 层检测到 cardType=0 + iOS 平台 → 降维 Fabric Component",
                    "description": "这是卡片列表中会优先命中 Fabric 原生视图的示例卡片，用于验证 C++ Props 绑定链路。",
                    "coverUrl": "https://images.unsplash.com/photo-1504639725590-34d0984388bd?w=800&auto=format&fit=crop",
                    "author": "Fabric Renderer",
                    "tag": "Fabric",
                    "timestamp": Date().timeIntervalSince1970 * 1000 - 3_600_000
                ],
                "actions": [
                    ["id": "b1", "title": "查看 Props", "actionType": 0],
                    ["id": "b2", "title": "分享", "actionType": 2]
                ]
            ]
        ]

        BusinessCardBridgeTurboModule.setInitialCardsPayload(
            (try? JSONSerialization.data(withJSONObject: mockCards)).flatMap {
                String(data: $0, encoding: .utf8)
            }
        )

        let cardVC = ReactNativeViewController(
            moduleName: "BusinessCardList",
            initialProperties: [
                "title": "发现 · 业务卡片",
                "subtitle": "Native 注入数据 + Fabric 原生渲染 + 热更新 Bundle" as Any,
                "enablePullRefresh": true
            ]
        )

        cardVC.onCardPress = { [weak self] cardId in
            DispatchQueue.main.async {
                self?.showAlert(title: "卡片点击", message: "cardId: \(cardId)\n该回调由 TurboModule 从 JS 桥回到原生")
            }
        }
        cardVC.onActionPress = { [weak self] cardId, actionId, actionType in
            DispatchQueue.main.async {
                self?.showAlert(
                    title: "操作按钮点击",
                    message: "cardId: \(cardId)\nactionId: \(actionId)\nactionType: \(actionType)"
                )
            }
        }
        cardVC.onExposure = { [weak self] cardId, timestamp in
            NSLog("[Native] 曝光上报 cardId=\(cardId) ts=\(timestamp)")
            self?.refreshStatus()
        }

        let navigationController = UINavigationController(rootViewController: cardVC)
        navigationController.modalPresentationStyle = .fullScreen
        present(navigationController, animated: true)
    }

    @objc
    private func switchEmbedded() {
        #if canImport(RNBridgePodspec)
        let ok = RNBridgeManager.shared.switchBundle(to: .embedded)
        showAlert(
            title: ok ? "✅ 切换成功" : "⏭ 无需切换",
            message: "已切换至内置 Bundle 源\n下一个 RN 页面将使用内置 main.jsbundle"
        )
        #else
        showAlert(title: "未启用 RNBridgePodspec", message: "请先执行 pod install 引入 RNBridgePodspec")
        #endif
    }

    @objc
    private func switchHotUpdate() {
        #if canImport(RNBridgePodspec)
        let ok = RNBridgeManager.shared.switchBundle(to: .hotUpdate)
        let url = RNBridgeManager.shared.resolveActiveBundleURL()
        showAlert(
            title: ok ? "✅ 切换成功" : (ok ? "⏭ 无需切换" : "⚠️ 未找到热更包"),
            message: """
            目标源: hotUpdate
            当前路径: \(url?.path ?? "(fallback 到内置)")
            请先通过 JS 侧 HotUpdateService 下载更新包
            """
        )
        #else
        showAlert(title: "未启用 RNBridgePodspec", message: "请先执行 pod install 引入 RNBridgePodspec")
        #endif
    }

    @objc
    private func reloadBundle() {
        NotificationCenter.default.post(
            name: NSNotification.Name.RCTJavaScriptDidLoad,
            object: nil
        )
        #if canImport(RNBridgePodspec)
        _ = RNBridgeManager.shared.switchBundle(to: RNBridgeManager.shared.bundleSource)
        #endif
        refreshStatus()
        showAlert(title: "🔄 已触发重载", message: "请重新打开 RN 页面查看最新 Bundle")
    }

    private static func makeCardButton(
        title: String,
        subtitle: String,
        color: UIColor,
        icon: String
    ) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.subtitle = subtitle
        config.image = UIImage(systemName: "square.grid.2x2.fill")
        config.imagePlacement = .leading
        config.imagePadding = 12
        config.cornerStyle = .large
        config.baseBackgroundColor = color
        config.contentInsets = NSDirectionalEdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)

        let titleAttr = AttributedString(
            "\(icon)  \(title)",
            attributes: AttributeContainer([.font: UIFont.systemFont(ofSize: 16, weight: .semibold)])
        )
        config.attributedTitle = titleAttr

        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.contentHorizontalAlignment = .leading
        return button
    }
}
