//
//  ViewController.swift
//  IM_Overseas_Package
//
//  Created by maochengfang on 2026/8/2.
//

import UIKit

final class ViewController: UIViewController {

    private let container = DemoAppContainer()

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let overviewLabel = UILabel()
    private let modeLabel = UILabel()
    private let packageLabel = UILabel()
    private let coreStack = UIStackView()
    private let featureStack = UIStackView()
    private let logTextView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        bindLifecycle()
        appendLogs([
            "Demo 已就绪：P0 主包只承载连接、存储、Push、文本聊天。",
            "P1/P2 能力通过懒加载模拟图片增强、贴纸资源、RTC 与搜索模块。"
        ])
        render()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configureUI() {
        title = "IM Overseas Demo"
        view.backgroundColor = .systemBackground

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.layoutMargins = UIEdgeInsets(top: 20, left: 16, bottom: 24, right: 16)
        contentStack.isLayoutMarginsRelativeArrangement = true

        overviewLabel.numberOfLines = 0
        overviewLabel.font = .systemFont(ofSize: 15)
        overviewLabel.textColor = .secondaryLabel
        overviewLabel.text = """
        面向弱网与低端机场景，主包仅保留登录、会话列表、文本聊天、存储、连接与 Push。图片增强、贴纸、RTC、搜索能力拆为独立模块，在业务入口懒加载。
        """

        modeLabel.numberOfLines = 0
        modeLabel.font = .systemFont(ofSize: 14, weight: .medium)

        packageLabel.numberOfLines = 0
        packageLabel.font = .systemFont(ofSize: 14)
        packageLabel.textColor = .label

        coreStack.axis = .vertical
        coreStack.spacing = 10

        featureStack.axis = .vertical
        featureStack.spacing = 10

        logTextView.isEditable = false
        logTextView.isScrollEnabled = false
        logTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        logTextView.backgroundColor = UIColor.secondarySystemBackground
        logTextView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        logTextView.layer.cornerRadius = 12
        logTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        let overviewSection = makeSection(
            title: "方案摘要",
            views: [overviewLabel, modeLabel, packageLabel]
        )
        let coreSection = makeSection(title: "P0 主包能力", views: [coreStack])
        let featureSection = makeSection(title: "P1 / P2 按需模块", views: [featureStack])
        let actionSection = makeSection(title: "交互操作", views: [makeActionButtons()])
        let logSection = makeSection(title: "运行日志", views: [logTextView])

        [overviewSection, coreSection, featureSection, actionSection, logSection].forEach {
            contentStack.addArrangedSubview($0)
        }
    }

    private func bindLifecycle() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    private func render() {
        let mode = container.mode
        modeLabel.text = "当前策略：\(mode.title)\n\(mode.description)"
        packageLabel.text = container.packageSummary

        coreStack.removeAllArrangedSubviews()
        container.coreItems.forEach { item in
            coreStack.addArrangedSubview(makeStatusCard(title: item.title,
                                                        badge: item.status,
                                                        badgeColor: item.color,
                                                        detail: item.detail))
        }

        featureStack.removeAllArrangedSubviews()
        container.featureItems.forEach { item in
            let title = "\(item.title) · \(item.tier)"
            let detail = """
            \(item.description)
            懒加载策略：\(item.loadStrategy)
            当前状态：\(item.stateText)
            """
            featureStack.addArrangedSubview(makeStatusCard(title: title,
                                                           badge: item.badgeText,
                                                           badgeColor: item.badgeColor,
                                                           detail: detail))
        }
    }

    private func makeActionButtons() -> UIView {
        let rows = UIStackView()
        rows.axis = .vertical
        rows.spacing = 10

        rows.addArrangedSubview(makeButtonRow([
            makeButton(title: "启动 P0 内核", action: #selector(startCoreTapped)),
            makeButton(title: "切换策略模式", action: #selector(cycleModeTapped))
        ]))

        rows.addArrangedSubview(makeButtonRow([
            makeButton(title: "加载图片增强", action: #selector(loadImageTapped)),
            makeButton(title: "加载贴纸资源", action: #selector(loadStickerTapped))
        ]))

        rows.addArrangedSubview(makeButtonRow([
            makeButton(title: "加载 RTC", action: #selector(loadRTCTapped)),
            makeButton(title: "加载搜索模块", action: #selector(loadSearchTapped))
        ]))

        rows.addArrangedSubview(makeButtonRow([
            makeButton(title: "重置 Demo", action: #selector(resetTapped), color: .systemGray)
        ]))

        return rows
    }

    private func makeButtonRow(_ buttons: [UIButton]) -> UIView {
        let row = UIStackView(arrangedSubviews: buttons)
        row.axis = .horizontal
        row.spacing = 10
        row.distribution = .fillEqually
        return row
    }

    private func makeButton(title: String, action: Selector, color: UIColor = .systemBlue) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = color
        button.layer.cornerRadius = 10
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func makeSection(title: String, views: [UIView]) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.text = title
        stack.addArrangedSubview(titleLabel)

        views.forEach { stack.addArrangedSubview($0) }

        let containerView = UIView()
        containerView.backgroundColor = UIColor.secondarySystemBackground
        containerView.layer.cornerRadius = 16
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
        ])

        return containerView
    }

    private func makeStatusCard(title: String, badge: String, badgeColor: UIColor, detail: String) -> UIView {
        let wrapper = UIView()
        wrapper.backgroundColor = .systemBackground
        wrapper.layer.cornerRadius = 12

        let vertical = UIStackView()
        vertical.axis = .vertical
        vertical.spacing = 8
        vertical.translatesAutoresizingMaskIntoConstraints = false

        let top = UIStackView()
        top.axis = .horizontal
        top.alignment = .center
        top.spacing = 8

        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.text = title
        titleLabel.numberOfLines = 0

        let badgeLabel = PaddingLabel()
        badgeLabel.backgroundColor = badgeColor
        badgeLabel.textColor = .white
        badgeLabel.font = .systemFont(ofSize: 12, weight: .bold)
        badgeLabel.text = badge
        badgeLabel.layer.cornerRadius = 8
        badgeLabel.clipsToBounds = true
        badgeLabel.textInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        top.addArrangedSubview(titleLabel)
        top.addArrangedSubview(spacer)
        top.addArrangedSubview(badgeLabel)

        let detailLabel = UILabel()
        detailLabel.numberOfLines = 0
        detailLabel.font = .systemFont(ofSize: 13)
        detailLabel.textColor = .secondaryLabel
        detailLabel.text = detail

        vertical.addArrangedSubview(top)
        vertical.addArrangedSubview(detailLabel)
        wrapper.addSubview(vertical)

        NSLayoutConstraint.activate([
            vertical.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 12),
            vertical.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 12),
            vertical.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -12),
            vertical.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -12)
        ])

        return wrapper
    }

    private func appendLogs(_ messages: [String]) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        let newEntries = messages.map { "[\(timestamp)] \($0)" }

        let existing = logTextView.text ?? ""
        let combined = (newEntries + (existing.isEmpty ? [] : [existing])).joined(separator: "\n")
        logTextView.text = combined
    }

    @objc private func startCoreTapped() {
        appendLogs(container.bootstrapCore())
        render()
    }

    @objc private func cycleModeTapped() {
        appendLogs(container.cycleMode())
        render()
    }

    @objc private func loadImageTapped() {
        appendLogs(container.load(.imageEnhancer))
        render()
    }

    @objc private func loadStickerTapped() {
        appendLogs(container.load(.stickerPack))
        render()
    }

    @objc private func loadRTCTapped() {
        appendLogs(container.load(.rtc))
        render()
    }

    @objc private func loadSearchTapped() {
        appendLogs(container.load(.search))
        render()
    }

    @objc private func resetTapped() {
        appendLogs(container.reset())
        render()
    }

    @objc private func handleDidEnterBackground() {
        appendLogs(container.handleDidEnterBackground())
        render()
    }

    @objc private func handleWillEnterForeground() {
        appendLogs(container.handleWillEnterForeground())
        render()
    }
}

private final class DemoAppContainer {
    private(set) var mode: DemoMode = .standard
    private(set) var isCoreBootstrapped = false
    private var featureModules = FeatureKind.allCases.map { FeatureModule(descriptor: $0.descriptor) }

    var packageSummary: String {
        """
        主包(P0)：登录、会话列表、文本聊天、SQLite/summary、连接层、Push 协同
        按需模块(P1/P2)：图片增强、贴纸资源、RTC、搜索增强
        当前模式说明：\(mode.packageRule)
        """
    }

    var coreItems: [StatusCardItem] {
        [
            StatusCardItem(
                title: "连接层",
                status: isCoreBootstrapped ? "已启动" : "未启动",
                color: isCoreBootstrapped ? .systemGreen : .systemOrange,
                detail: "负责 WebSocket 建连、重连、探活与前后台切换。P0 主包必须内置，不能延后到媒体模块。"),
            StatusCardItem(
                title: "存储层",
                status: isCoreBootstrapped ? "可用" : "待激活",
                color: isCoreBootstrapped ? .systemGreen : .systemOrange,
                detail: "使用 SQLite/summary 模型承载消息与会话摘要，避免首屏扫描全量消息。"),
            StatusCardItem(
                title: "Push 协同",
                status: isCoreBootstrapped ? "纠偏中" : "待激活",
                color: isCoreBootstrapped ? .systemBlue : .systemOrange,
                detail: "Push 仅做提醒与 sync_hint，最终一致性通过回前台对账与 seq 补拉达成。"),
            StatusCardItem(
                title: "策略引擎",
                status: mode.title,
                color: mode.color,
                detail: mode.description
            )
        ]
    }

    var featureItems: [FeatureCardItem] {
        featureModules.map { module in
            FeatureCardItem(
                title: module.descriptor.title,
                tier: module.descriptor.tier.rawValue,
                description: module.descriptor.description,
                loadStrategy: module.descriptor.loadStrategy,
                stateText: module.state.detailText,
                badgeText: module.state.badgeText,
                badgeColor: module.state.color
            )
        }
    }

    func bootstrapCore() -> [String] {
        guard !isCoreBootstrapped else {
            return ["P0 内核已启动，当前仍保持最小可用主包，不重复初始化媒体/RTC 模块。"]
        }

        isCoreBootstrapped = true
        return [
            "启动 P0 内核：初始化连接、存储、Push 协同、文本聊天基础链路。",
            "主包维持最小可用，不预加载图片增强、贴纸、RTC、搜索模块。"
        ]
    }

    func cycleMode() -> [String] {
        mode = mode.next
        var logs = ["切换到\(mode.title)：\(mode.description)"]

        for module in featureModules where module.state == .loaded {
            if let forcedMessage = module.forceFallbackIfNeeded(mode: mode) {
                logs.append(forcedMessage)
            }
        }

        return logs
    }

    func load(_ kind: FeatureKind) -> [String] {
        guard isCoreBootstrapped else {
            return ["请先启动 P0 内核，确保连接、存储与离线能力先可用。"]
        }

        guard let module = featureModules.first(where: { $0.descriptor.kind == kind }) else {
            return ["未找到对应模块。"]
        }

        return [module.load(mode: mode)]
    }

    func reset() -> [String] {
        isCoreBootstrapped = false
        mode = .standard
        featureModules.forEach { $0.reset() }
        return [
            "Demo 已重置：回到最小可用主包状态。",
            "P1/P2 模块全部置为未加载，等待业务入口触发懒初始化。"
        ]
    }

    func handleDidEnterBackground() -> [String] {
        guard isCoreBootstrapped else {
            return []
        }
        return ["应用进入后台：停止激进探活，保留最小同步能力，等待 Push 或回前台纠偏。"]
    }

    func handleWillEnterForeground() -> [String] {
        guard isCoreBootstrapped else {
            return []
        }
        return ["应用回到前台：触发 summary 对账与 seq 缺口补拉，确保未读数和会话状态最终一致。"]
    }
}

private final class FeatureModule {
    let descriptor: FeatureDescriptor
    private(set) var state: ModuleState = .unloaded

    init(descriptor: FeatureDescriptor) {
        self.descriptor = descriptor
    }

    func load(mode: DemoMode) -> String {
        if state == .loaded {
            return "\(descriptor.title) 已处于加载完成状态，无需重复初始化。"
        }

        if let fallbackMessage = fallbackReason(mode: mode) {
            state = .fallback
            return fallbackMessage
        }

        state = .loaded
        return "\(descriptor.title) 懒加载成功：\(descriptor.loadSuccessMessage)"
    }

    func forceFallbackIfNeeded(mode: DemoMode) -> String? {
        guard state == .loaded, let fallbackMessage = fallbackReason(mode: mode) else {
            return nil
        }

        state = .fallback
        return fallbackMessage
    }

    func reset() {
        state = .unloaded
    }

    private func fallbackReason(mode: DemoMode) -> String? {
        switch (descriptor.kind, mode) {
        case (.rtc, .weakNetwork),
             (.rtc, .lowMemory),
             (.rtc, .lowPerformance):
            return "RTC 模块被策略引擎降级：当前\(mode.title)下默认不展示视频能力，回退为语音优先或入口隐藏。"
        case (.imageEnhancer, .weakNetwork),
             (.imageEnhancer, .lowMemory):
            return "图片增强模块未真正加载：当前\(mode.title)只保留 P0 缩略图与手动加载原图能力。"
        case (.stickerPack, .weakNetwork),
             (.stickerPack, .lowMemory):
            return "贴纸资源延迟到更优网络/内存环境下载：当前\(mode.title)仅保留主包基础 emoji。"
        case (.search, .lowMemory):
            return "搜索增强模块回退：当前\(mode.title)只允许服务端搜索或最近 N 条轻量搜索。"
        default:
            return nil
        }
    }
}

private struct StatusCardItem {
    let title: String
    let status: String
    let color: UIColor
    let detail: String
}

private struct FeatureCardItem {
    let title: String
    let tier: String
    let description: String
    let loadStrategy: String
    let stateText: String
    let badgeText: String
    let badgeColor: UIColor
}

private struct FeatureDescriptor {
    let kind: FeatureKind
    let title: String
    let tier: ModuleTier
    let description: String
    let loadStrategy: String
    let loadSuccessMessage: String
}

private enum DemoMode: CaseIterable {
    case standard
    case weakNetwork
    case lowMemory
    case lowPerformance

    var title: String {
        switch self {
        case .standard: return "标准模式"
        case .weakNetwork: return "弱网模式"
        case .lowMemory: return "低内存模式"
        case .lowPerformance: return "低性能模式"
        }
    }

    var description: String {
        switch self {
        case .standard:
            return "允许按需拉起图片增强、贴纸、RTC 与搜索模块，用于演示完整的 P1/P2 扩展路径。"
        case .weakNetwork:
            return "优先保文本收发与恢复一致性，图片增强/贴纸延迟，RTC 默认降级。"
        case .lowMemory:
            return "收紧图片/贴纸/搜索增强，避免大图解码、资源包下载与高峰值内存占用。"
        case .lowPerformance:
            return "保留基础聊天体验，限制高 CPU 的视频/RTC 能力，优先稳定和耗电控制。"
        }
    }

    var packageRule: String {
        switch self {
        case .standard:
            return "可以按业务入口懒加载 P1/P2 模块。"
        case .weakNetwork:
            return "禁止自动下载大图/贴纸，RTC 默认不激活。"
        case .lowMemory:
            return "图片增强与贴纸资源回退到主包基础能力。"
        case .lowPerformance:
            return "高 CPU 模块延迟或关闭，保留文本与基础图片。"
        }
    }

    var color: UIColor {
        switch self {
        case .standard: return .systemBlue
        case .weakNetwork: return .systemOrange
        case .lowMemory: return .systemPink
        case .lowPerformance: return .systemPurple
        }
    }

    var next: DemoMode {
        switch self {
        case .standard: return .weakNetwork
        case .weakNetwork: return .lowMemory
        case .lowMemory: return .lowPerformance
        case .lowPerformance: return .standard
        }
    }
}

private enum ModuleTier: String {
    case p1 = "P1"
    case p2 = "P2"
}

private enum ModuleState {
    case unloaded
    case loaded
    case fallback

    var badgeText: String {
        switch self {
        case .unloaded: return "未加载"
        case .loaded: return "已加载"
        case .fallback: return "已降级"
        }
    }

    var detailText: String {
        switch self {
        case .unloaded: return "未进入主包，等待业务入口触发懒加载。"
        case .loaded: return "模块已按需加载，可在不改 P0 主包的前提下扩展能力。"
        case .fallback: return "当前策略不允许真正启用模块，已回退到主包基础能力。"
        }
    }

    var color: UIColor {
        switch self {
        case .unloaded: return .systemGray
        case .loaded: return .systemGreen
        case .fallback: return .systemOrange
        }
    }
}

private enum FeatureKind: CaseIterable {
    case imageEnhancer
    case stickerPack
    case rtc
    case search

    var descriptor: FeatureDescriptor {
        switch self {
        case .imageEnhancer:
            return FeatureDescriptor(
                kind: self,
                title: "图片增强模块",
                tier: .p1,
                description: "P0 主包仅保留缩略图与手动加载原图。P1 再提供高级预览、渐进加载与编辑能力。",
                loadStrategy: "业务进入图片预览页时懒初始化，避免冷启动解码和缓存初始化成本。",
                loadSuccessMessage: "已启用高级预览与更强缓存，但不会改变 P0 文本聊天主路径。"
            )
        case .stickerPack:
            return FeatureDescriptor(
                kind: self,
                title: "贴纸资源模块",
                tier: .p1,
                description: "贴纸与表情包不打进主包，通过远程资源或 ODR 懒加载，按地区和热度下发。",
                loadStrategy: "用户首次进入贴纸面板时请求资源包，失败时回退到主包 emoji。",
                loadSuccessMessage: "已模拟拉取远程贴纸资源，可独立演进而不影响主包。"
            )
        case .rtc:
            return FeatureDescriptor(
                kind: self,
                title: "RTC 模块",
                tier: .p2,
                description: "音视频能力独立于 P0 主包，避免引入大型 SDK、编解码初始化与耗电开销。",
                loadStrategy: "仅在用户进入通话入口时懒初始化，弱网/低端场景直接降级为语音或不展示。",
                loadSuccessMessage: "已模拟加载独立 RTC 框架，仍保持主包只关注文本 IM。"
            )
        case .search:
            return FeatureDescriptor(
                kind: self,
                title: "搜索增强模块",
                tier: .p2,
                description: "主包只保留基础聊天与 summary，同步搜索增强能力按机型与内存分层开放。",
                loadStrategy: "仅在进入搜索页时创建索引/查询上下文，低内存下回退到服务端或最近 N 条。",
                loadSuccessMessage: "已模拟加载搜索增强能力，支持后续接入本地索引或服务端混合搜索。"
            )
        }
    }
}

private final class PaddingLabel: UILabel {
    var textInsets = UIEdgeInsets.zero

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: textInsets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + textInsets.left + textInsets.right,
                      height: size.height + textInsets.top + textInsets.bottom)
    }
}

private extension UIStackView {
    func removeAllArrangedSubviews() {
        arrangedSubviews.forEach { view in
            removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }
}
